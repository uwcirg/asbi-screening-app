const path = require("path");
const systemType = String(process.env.VUE_APP_SYSTEM_TYPE).toLowerCase();
module.exports = {
  configureWebpack: {
    devtool: systemType === "development" ? "source-map" : "",
    module: {
      rules: [
        {
          test: /\.js$/,
          use: ["source-map-loader"],
          enforce: "pre",
          exclude: [
            path.resolve(__dirname, "node_modules"),
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
        {
          test: /\.js$/,
          use: {
            loader: require.resolve("@open-wc/webpack-import-meta-loader"),
          }
        },
      ],
    },
  },
  publicPath: "/",
  pages: {
    index: "./src/main.js",
    launch: "./src/launch.js",
  },
  transpileDependencies: ["questionnaire-to-survey", "encender"],
};
