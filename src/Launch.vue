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
import {queryPatientIdKey, queryIssKey} from './util/util.js';

const urlParams = new URLSearchParams(window.location.search);
let patientId = urlParams.get('patient');
let iss = urlParams.get('iss');
console.log("iss ", iss)
//if (patientId == null) patientId = '123';
console.log("patient id from url ", patientId);

export default {
  name: 'Launch',
  data() {
    return {
      error: ""
    }
  },
  mounted() {
    let self = this;
    
    sessionStorage.removeItem(queryPatientIdKey); //remove any stored patient id before launching the app
    sessionStorage.removeItem(queryIssKey);
    
    fetch('launch-context.json', {
      // include cookies in request
      credentials: 'include'
    })
    .then(result => {
      if (!result.ok) {
        throw Error(result.status);
      }
      return result.json();
    })
    .catch(e => self.error=e)
    .then(json => {
      if (patientId) {
        //only do this IF patient id comes from url queryString
        json.patientId = patientId;
        sessionStorage.setItem(queryPatientIdKey, patientId);
      }
      if (iss) {
        sessionStorage.setItem(queryIssKey, iss);
      }
      console.log("launch context json ", json);
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
