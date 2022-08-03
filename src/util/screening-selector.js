import valueSetJson from "../cql/valueset-db.json";
import { getEnv } from "./util.js";

//dynamically load questionnaire and cql JSON
export async function getScreeningInstrument(client) {
  const envScreeningInstrument = getEnv("VUE_APP_SCREENING_INSTRUMENT");
  let screeningInstrument = envScreeningInstrument
    ? envScreeningInstrument.toLowerCase()
    : "";
  console.log("screening instrument to be loaded", screeningInstrument);
  if (!screeningInstrument) {
    throw new Error("No screening instrument specified");
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
    if (!client) throw new Error("invalid FHIR client provided");
    let libId = screeningInstrument.toUpperCase();
    // load questionnaire from FHIR server
    const qSearch = await client
      .request("/Questionnaire?name="+screeningInstrument)
      .catch((e) => {
        throw new Error(`Error retrieving questionnaire: ${e}`);
      });
    let questionnaireJson;
    if (qSearch && qSearch.entry && qSearch.entry.length > 0) {
      questionnaireJson = qSearch.entry[0].resource;
    }
    if (!questionnaireJson) {
      throw new Error("No matching questionnaire returned from the server.");
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
