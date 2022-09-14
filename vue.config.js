const path = require('path');
const systemType = String(process.env.VUE_APP_SYSTEM_TYPE).toLowerCase();
module.exports = {
  // chainWebpack: (config) => {
  //   config.module
  //     .rule("vue")
  //     .use("vue-loader")
  //     .tap((options) => {
  //       options.compiler = require("vue-template-babel-compiler");
  //       return options;
  //     });
  // },
  chainWebpack: config => {
    config.module
      .rule("supportChaining")
      .test(/\.js$/)
      .include.add(path.resolve("node_modules/questionnaire-to-survey"))
      .end()
      .use("babel-loader")
      .loader("babel-loader")
      .tap((options) => ({
        ...options,
        plugins: [
          "@babel/plugin-proposal-optional-chaining",
          "@babel/plugin-proposal-nullish-coalescing-operator"
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
