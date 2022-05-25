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
    fetch(`launch-context.json`)
    .then(result => {
      if (!result.ok) {
        throw Error(result.statusText);
      }
      return result.json();
    })
    .then(json => {
      if (!json.launch) {
        json.launch = patientId;
      }
      FHIR.oauth2.authorize(json).catch((e) => {
        self.error = e;
      });
    })
    .catch(e => {
      self.error = e;
      console.log('launch error ', e);
    });
  }
}
</script>
