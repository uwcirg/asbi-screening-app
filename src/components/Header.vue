<template>
   <v-app-bar
        dark
        dense
        color="primary"
        elevation=2
        app>
        <v-toolbar-title v-text="title"></v-toolbar-title>
        <v-spacer></v-spacer>
        <div class="mr-6">
            <div class="text-subtitle-2 white--text" v-if="hasPatientName()" v-text="getPatientName()"></div>
            <div class="text-subtitle-2 white--text" v-text="getPatientDob()"></div>
        </div>
    </v-app-bar>
</template>

<script>
  export default {
    props: {
      patient: Object,
      title: String
    },
    methods: {
      hasPatientName () {
        return this.patient && this.patient.name && this.patient.name.length;
      },
      getPatientName () {
        if (!this.hasPatientName()) return '';
        return [this.patient.name[0].family, this.patient.name[0].given[0]].join(', ');
      },
      getPatientDob () {
        if (!this.patient || !this.patient.birthDate) return '';
        return this.patient.birthDate;
      }
    }
  };
</script>
