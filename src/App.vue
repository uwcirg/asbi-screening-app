<template>
  <v-app id="app">
    <Header 
      :title="title"
      :patient="patient"
      v-if="ready">
    </Header>
    <Survey
      :client="client"
      :patient="patient"
      :authError="error"
      @finished="finished"/>
  </v-app>
</template>
<script>
import FHIR from 'fhirclient';
import 'survey-vue/modern.css';
import './style/app.scss';
import Header from './components/Header';
import Survey from './components/Survey';
import {queryPatientIdKey} from './util/util';

const DEFAULT_TITLE = 'Screening Instrument';

export default {
  name: 'App',
  components: {
    Header,
    Survey
  },
  data() {
    return {
      title: process.env.VUE_APP_TITLE?process.env.VUE_APP_TITLE:DEFAULT_TITLE,
      client: null,
      patient: null,
      error: '',
      ready: false
    }
  },
  async mounted() {
    try {
      this.client = await this.setAuthClient();
    } catch(e) {
      this.error = e;
    }
    if (!this.error) {
      try {
        this.patient = await this.setPatient().catch(e => this.error = e);
      } catch(e) {
        this.error = e;
      }
      if (!this.error && (!this.patient || !this.patient.id)) {
        this.error = "No valid patient is set.";
      }
    }
    this.ready = true;
  },
  methods: {
    async setAuthClient() {
      let authClient;
       // Wait for authorization
      try {
        authClient = await FHIR.oauth2.ready();
      } catch(e) {
        throw new Error('Auth error: '+ e);
      }
      return authClient;
    },
    async setPatient() {
      //patient id was coming from url query string parameter and stored as sessionStorage item
      let queryPatientId = sessionStorage.getItem(queryPatientIdKey);
      if (queryPatientId) {
        console.log("Patient id unavailable from client object. Using stored patient id ", queryPatientId);
        return this.client.request('/Patient/'+queryPatientId);
      }
      let pt;
       //set patient
      try {
        pt = await this.client.patient.read().then((pt) => {
          return pt;
        });
      } catch(e) {
        throw new Error('Unable to read patient info: ' + e);
      }
      return pt;
    },
    finished(data) {
      if (!data) return;
      if ((!this.title || this.title === DEFAULT_TITLE) && data.title) this.title = data.title;
    }
  }
}
</script>
