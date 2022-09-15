const path = require('path');
const systemType = String(process.env.VUE_APP_SYSTEM_TYPE).toLowerCase();
module.exports = {
  chainWebpack: config => {
    config.module
      .rule("supportChaining")
      .test(/\.js$/)
      // questionnaire-to-survey as of version 2.3.1 introduces ES2020 syntax, optional-chaining and nullish-coalescing-operator
      // not supported by Vue 2, looks like supported in Vue 3, TODO upgrade Vue version
      // for now, add babel plugins to correctly transpile those
      .include.add(path.resolve("node_modules/questionnaire-to-survey"))
      .end()
      .use("babel-loader")
      .loader("babel-loader")
      .tap((options) => ({
        ...options,
        plugins: [
          "@babel/plugin-proposal-optional-chaining",
          "@babel/plugin-proposal-nullish-coalescing-operator",
        ],
      }))
      .end();
  },
  configureWebpack: {
    devtool: systemType === "development" ? "source-map" : "",
    module: {
      rules: [
        {
          test: /\.js$/,
          use: ["source-map-loader"],
          enforce: "pre",
          exclude: [
            path.resolve(__dirname, "node_modules/cql-execution/lib"),
            path.resolve(__dirname, "node_modules/fhirclient"),
            path.resolve(__dirname, "node_modules/cql-worker"),
            path.resolve(__dirname, "node_modules/cql-exec-fhir"),
          ],
        },
        {
          test: /\.worker\.js$/,
          use: {
            loader: "worker-loader",
            options: {
              publicPath: "/src/cql/",
              inline: true,
            },
          },
        },
        {
          test: /\.js\.map$/,
          use: ["ignore-loader"],
        },
      ],
    },
  },
  publicPath: "/",
  pages: {
    index: "./src/main.js",
    launch: "./src/launch.js",
  },
  transpileDependencies: ["vuetify"],
};
