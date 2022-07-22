//dynamically load css for a questionnaire
export function getInstrumentCSS() {
  let screeningInstrument = process.env.VUE_APP_SCREENING_INSTRUMENT ? 
  process.env.VUE_APP_SCREENING_INSTRUMENT.toLowerCase() : "";
  switch(screeningInstrument) {
    case "minicog":
      return import("../style/minicog.scss");
    default:
      return "";
  }
}
