<template>
  <v-progress-circular
    :size="size"
    :width="width"
    indeterminate
    color="primary"
  ></v-progress-circular>
</template>
<script>
export default {
  props: {
    size: {
      type: String,
      default: "56",
    },
    width: {
      type: String,
      default: "4",
    },
  },
};
</script>
