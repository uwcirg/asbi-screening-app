import valueSetJson from "../cql/valueset-db.json";
import { getEnv } from "./util.js";

//dynamically load questionnaire and cql JSON
export async function getScreeningInstrument(client, patientId) {
  if (!client) throw new Error("invalid FHIR client provided");
  let screeningInstrument = "";
  if (patientId) {
    const carePlan = await client.request(`CarePlan?subject=Patient/${patientId}&_sort=-_lastUpdated`);
    if (carePlan && carePlan.entry && carePlan.entry.length) {
      const resources = carePlan.entry;
      // TODO: need to figure out which one is the next questionnaire to do
      // For now, assumming the first one in the activity array is the next questionnaire to do?
      if (resources.length) {
        const activities = resources[0].resource? resources[0].resource.activity: null;
        if (activities) {
          const canonicalIdentifier = activities[0].detail && activities[0].detail.instantiatesCanonical ? activities[0].detail.instantiatesCanonical[0]: null;
          if (canonicalIdentifier) {
            //assuming instantiatesCanonical references questionnaire in format like this:  Questionnaire/[Questionnaire ID]
            screeningInstrument = canonicalIdentifier.split("/")[1];
          }
          console.log("Screening instrument specified in careplan ", screeningInstrument);
        }
      }
    }
  }
  // if we don't find a specified questionnaire from a patient's careplan,
  // we look to see if it is specifed in the environment variable
  if (!screeningInstrument) screeningInstrument = getEnv("VUE_APP_SCREENING_INSTRUMENT");
  if (!screeningInstrument) {
    throw new Error("No screening instrument specified.");
  }
  if (screeningInstrument == "usaudit") {
    let questionnaireUsAudit = await import(
      "../fhir/Questionnaire-USAUDIT.json"
    ).then((module) => module.default);
    let elmJsonUsAudit = await import("../cql/UsAuditLogicLibrary.json").then(
      (module) => module.default
    );
    return [questionnaireUsAudit, elmJsonUsAudit, valueSetJson];
  } else if (screeningInstrument == "whoaudit") {
    let questionnaireWhoAudit = await import(
      "../fhir/Questionnaire-WHOAUDIT.json"
    ).then((module) => module.default);
    let elmJsonWhoAudit = await import("../cql/WhoAuditLogicLibrary.json").then(
      (module) => module.default
    );
    return [questionnaireWhoAudit, elmJsonWhoAudit, valueSetJson];
  } else if (screeningInstrument == "nidaqs2usaudit") {
    let questionnaireNidaQs = await import(
      "../fhir/Questionnaire-NIDAQS2USAUDIT.json"
    ).then((module) => module.default);
    let elmJsonNidaQs = await import(
      "../cql/NidaQsToUsAuditLogicLibrary.json"
    ).then((module) => module.default);
    return [questionnaireNidaQs, elmJsonNidaQs, valueSetJson];
  } else {
    let libId = screeningInstrument.toUpperCase();
    // load questionnaire from FHIR server
    const qSearch = await client
      // look up the questionnaire based on whether the id or the name attribute matches the specified instrument id?
      .request("/Questionnaire?_id|name:contains="+screeningInstrument)
      .catch((e) => {
        throw new Error(`Error retrieving questionnaire: ${e}`);
      });
    let questionnaireJson;
    if (qSearch && qSearch.entry && qSearch.entry.length > 0) {
      questionnaireJson = qSearch.entry[0].resource;
    } else {
      // load from file and post it
      const fileJson = await import(
        `../fhir/Questionnaire-${screeningInstrument.toUpperCase()}.json`
      ).then((module) => module.default).catch(e => console.log("Error retrieving matching questionnaire JSON from filesystem ", e));
      if (fileJson) {
        questionnaireJson = await client.create(fileJson, {
          headers: {
            "Content-Type": "application/fhir+json",
          },
        }).catch(e => console.log("Error storing questionnaire ", e));
      }
    }
    if (!questionnaireJson) {
      throw new Error("No matching questionnaire found.");
    }
    let elmJson;
    try {
      elmJson = await import(`../cql/${libId}_LogicLibrary.json`).then(
        (module) => module.default
      );
    } catch (e) {
      console.log("error ", e);
      throw new Error(
        "Error loading ELM library. Unsupported ELM library may have been specified " + e
      );
    }
    return [questionnaireJson, elmJson, valueSetJson];
  }
}
