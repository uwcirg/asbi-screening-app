import Worker from "cql-worker/src/cql.worker.js"; // https://github.com/webpack-contrib/worker-loader
import { initialzieCqlWorker } from "cql-worker";
import valueSetJson from "../cql/valueset-db.json";
//import QuestionnaireLogicLibrary from "../cql/QuestionnaireLogicLibrary.json";
import {getEnv} from "./util";

function fetchResources(client, patientId) {
  const requests = [
    "Patient/" + patientId,
    "Questionnaire",
    "QuestionnaireResponse",
  ].map((item) => {
    return client.request(item, {
        pageLimit: 0
    });
  });
  return Promise.all(requests);
}

// Define a web worker for evaluating CQL expressions
  const cqlWorker = new Worker();
  // Initialize the cql-worker
  let [setupExecution, sendPatientBundle, evaluateExpression] =
    initialzieCqlWorker(cqlWorker);

export const applyDefinition = async (planDefinitionId, client, patientId) => {
  

  let patientBundle = {
    resourceType: "Bundle",
    id: "survey-bundle",
    type: "collection",
    entry: [],
  };

  if (!planDefinitionId)
    planDefinitionId = getEnv("VUE_APP_PLAN_DEFINITION_ID");

  if (!planDefinitionId) throw new Error("A valid plan definition ID must be supplied");

  //get plan definition json
  const QuestionnaireLogicLibrary = await import(
    `../cql/QuestionnaireLogicLibrary_${planDefinitionId}.json`
  )
    .then((module) => module.default)
    .catch((e) => {
      throw new Error(e);
    });

  //get corresponding logic library
  const planDef = await import(
    `../fhir/2_PlanDefinition_${planDefinitionId}.json`
  )
    .then((module) => module.default)
    .catch((e) => {
      throw new Error(e);
    });

  
  console.log("Plan def ", planDef);

  const results = await fetchResources(client, patientId).catch((e) => {
    console.log("Error retrieving FHIR resources ", e);
  });
  console.log("FIR results ", results)
  results.forEach((result) => {
    console.log("result ", result)
    if (result.resourceType == "Bundle" && result.entry) {
      result.entry.forEach((o) => {
        if (o && o.resource) patientBundle.entry.push({ resource: o.resource });
      });
    } else if (Array.isArray(result)) {
      result.forEach((o) => {
        if (o.resourceType == "Bundle" && o.entry) {
          o.entry.forEach(item => {
            if (item && item.resource) {
              patientBundle.entry.push({ resource: item.resource });
            }
          })
        }
        else patientBundle.entry.push({ resource: o });
      });
    } else {
      patientBundle.entry.push({ resource: result });
    }
  });

  console.log("patient bundle ", patientBundle)

  console.log("questionnaire lib logic ", QuestionnaireLogicLibrary);

  // Send the cqlWorker an initial message containing the ELM JSON representation of the CQL expressions
  setupExecution(QuestionnaireLogicLibrary, valueSetJson, {}); //empty CQL parameters for now
  sendPatientBundle(patientBundle);
   const actions = planDef.action;
   const evaluations = []
  // let list = [];

   if (Array.isArray(actions)) {
     actions.forEach((action) => {
       if (Array.isArray(action.condition)) {
         action.condition.forEach((item) => {
           if (
             item.kind === "applicability" &&
             item.expression &&
             item.expression.language === "text/cql"
           ) {
            console.log("expression ? ", item.expression.expression)
            evaluations.push(evaluateExpression(item.expression.expression));
           }
         });
       }
     });
   }

   let evalResults = await Promise.all(evaluations);
   console.log("all the results ", evalResults);

   const patientResource = patientBundle.entry.filter(entry => entry.resource.resourceType === "Patient").map(entry => entry.resource)[0]
   console.log("patientResource ", patientResource);
   const patientName = [patientResource.name[0].family, patientResource.name[0].given[0]];
   console.log("patient id ", patientId);
   console.log("patient name ", patientName.join(", "));

   let carePlan = {
     resourceType: "CarePlan",
     status: "active",
     intent: "order",
     category: [
       {
         coding: [
           {
             system: "http://snomed.info/sct",
             code: "719091000000102",
             display: "Questionnaire",
           },
         ],
         text: "Questionnaire",
       },
     ],
   };
   carePlan.subject = {
      reference: "Patient/"+patientId,
      display: patientName
   };
   evalResults = evalResults.filter(result => result);
   if (evalResults) {
    let activities = [];
    evalResults.forEach(result => {
      activities.push({
        detail: {
          instantiatesCanonical: ["Questionnaire/"+result],
          status:"scheduled"
        }
      })
    })
    if (activities.length) {
      carePlan.activity = activities;
    }
   }

   console.log("carePlan ", carePlan);

   //TODO post this
   return carePlan

};

export default applyDefinition;
