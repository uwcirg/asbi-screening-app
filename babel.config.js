module.exports = {
  presets: [
    [
      "@vue/cli-plugin-babel/preset",
      {
        targets: {
          browsers: ["last 2 versions", "safari >= 7"],
          node: "current",
        },
      },
    ],
  ],
  plugins: [
    "@babel/plugin-proposal-optional-chaining",
    "@babel/plugin-proposal-nullish-coalescing-operator",
  ],
};
