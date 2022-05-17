<template>
  <v-app id="launch">
    <div class="pa-8" v-if="!error">
      <v-progress-circular
      :value="100"
      indeterminate
      color="primary"
      class="mr-1"></v-progress-circular>
      Loading...
    </div>
    <div class="pa-8" v-if="error">
      <v-alert color="error" v-if="error" dark>
        Error launch the application.
        <div v-html="error"></div>
      </v-alert>
    </div>
  </v-app>
</template>

<script>
import FHIR from 'fhirclient';
const urlParams = new URLSearchParams(window.location.search);
let patientId = urlParams.get('patient');
if (patientId == null) patientId = '123';

export default {
  name: 'Launch',
  data() {
    return {
      error: ""
    }
  },
  mounted() {
    let self = this;
    FHIR.oauth2.authorize({
      clientId: "dummy-client-id",
      scope: "patient/Patient.read patient/Condition.read patient/Observation.read patient/Procedure.read patient/QuestionnaireResponse.read online_access openid fhirUser patient/QuestionnaireResponse.write",
      iss: "http://localhost:3000/4_0_0",
      launch: patientId
    }).catch((e) => {
      self.error = e;
    });
  }
}
</script>

<style>
</style>
