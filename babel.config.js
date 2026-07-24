module.exports = function (api) {
  api.cache(true);
  return {
    presets: ['babel-preset-expo'],
    plugins: [
      [
        'module-resolver',
        {
          alias: { '@': './src' },
          extensions: ['.ts', '.tsx', '.js', '.jsx', '.json'],
        },
      ],
      // Down-level `#private` / class fields so this Hermes build accepts them.
      // Use SPEC mode (loose:false): loose mode emits plain assignments
      // (`this.NONE = …`) which throw "Cannot assign to read-only property"
      // against RN's read-only base classes (DOMRectReadOnly, Event, etc.).
      ['@babel/plugin-transform-private-methods', { loose: false }],
      ['@babel/plugin-transform-class-properties', { loose: false }],
      ['@babel/plugin-transform-private-property-in-object', { loose: false }],
    ],
  };
};
