import { applyPlan, simpleResolver } from "encender";
import Worker from "cql-worker/src/cql.worker.js"; // https://github.com/webpack-contrib/worker-loader
import fhirHelperJson from "../cql/FHIRHelpers-4.0.1";
import QuestionnaireLogicLibrary from "../cql/QuestionnaireLogicLibrary.json";
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

const applyDefinition = async (planDefinitionId, client, patientId) => {

    if (!planDefinitionId) planDefinitionId = getEnv(
                             "VUE_APP_PLAN_DEFINITION_ID"
                           );
    //get plan definition json
    const planDef = await import(`../fhir/2_PlanDefinition_${planDefinitionId}.json`).then(
      (module) => module.default
    );
    //console.log("Plan def ", planDef);

    let resources = [];
    fetchResources(client, patientId).then((results) => {
        results.forEach((result) => {
            if (result.resourceType == "Bundle" && result.entry) {
            result.entry.forEach((o) => {
                if (o && o.resource) resources.push(o.resource);
            });
            } else if (Array.isArray(result)) {
            result.forEach((o) => {
                if (o.resourceType) resources.push(o);
            });
            } else {
            resources.push(result);
            }
        });
    })
    // const patientReference = resources.filter(item => item.resourceType === "Patient")[0];
    const patientReference = "/Patient/" + patientId;

    // Read in ELM JSON representation of CDS logic
    const elmJsonDependencyArray = [
        QuestionnaireLogicLibrary,
        fhirHelperJson
    ];

    // Reformat ELM JSON value set references to match what is expected by the
    // code service built into the cql execution engine
    const elmJsonDependencies = elmJsonDependencyArray.reduce((acc, elm) => {
        let refs = elm?.library?.valueSets?.def;
        if (refs) {
        refs = refs.map((r) => {
            return {
            ...r,
            id: r.id.split("/").pop(),
            };
        });
        elm.library.valueSets.def = refs;
        }
        return {
        ...acc,
        [elm.library.identifier.id]: elm,
        };
    }, {});

    //console.log("ELM dependencies ", JSON.stringify(elmJsonDependencies, null, 4));

    // Create resolver() function
    const resolver = simpleResolver(resources);
    //console.log(resolver);
    // console.log(resources);

    console.log("elms ", elmJsonDependencies);
    const WorkerFactory = () => {
        return new Worker(new URL('cql-worker/src/cql.worker.js', import.meta.url));
      }
    
    const isNodeJs = false;
    // Define aux object containing ELM JSON and value sets
    const aux = {
      elmJsonDependencies,
      WorkerFactory,
      isNodeJs
    };

    //const planDef = JSON.parse(readFileSync("CQL/PlanDefinition.json"));
    //console.log("Plan def ", planDef);

    // Run the $apply operations
    //   applyAndMerge(planDef, patientReference, resolver, aux).then((results) => {
    //     const [RequestGroup, ...otherResources] = results;
    //     console.log("RequestGroup ", RequestGroup);
    //     console.log("OtherResources, ", otherResources);
    //     let outputResources = [RequestGroup, otherResources, resources];
    //     // Write them out to a file
    //     writeFileSync(
    //       "CQL/screeningOutput.json",
    //       JSON.stringify(outputResources, null, 2)
    //     );
    //   });

    applyPlan(planDef, patientReference, resolver, aux).then((results) => {
        const [CarePlan, RequestGroup, ...otherResources] = results;
        console.log("CarePlan ", JSON.stringify(CarePlan, null, 2));
        console.log("RequestGroup ", RequestGroup);
        console.log("Other resources ", otherResources);
        let outputResources = [CarePlan, RequestGroup, otherResources];
        console.log("outputResources" , outputResources)
        // // Write them out to a file
        // writeFileSync("CQL/output.json", JSON.stringify(outputResources, null, 2));
    });
};

export default applyDefinition;
