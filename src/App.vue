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

export default {
  name: 'App',
  components: {
    Header,
    Survey
  },
  data() {
    return {
      title: 'Screener',
      client: null,
      patient: null,
      error: '',
      ready: false
    }
  },
  mounted() {
    this.setAuthClient().then((result) => {
      this.client = result;
      this.setPatient().then((patient) => {
        if (!patient || !patient.id) {
          this.ready = true;
          this.error = "No valid patient is set.";
          return;
        }
        this.patient = patient;
        this.ready = true;
      }).catch(e => {
        this.ready = true;
        this.error = e;
        console.log("Set patient error ", e);
      });
    }).catch(e => {
      this.ready = true;
      this.error = e;
      console.log("Auth Error ", e);
    });
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
      if (data.title) this.title = data.title;
      //others set from survey data if needed
    }
  }
}
</script>
