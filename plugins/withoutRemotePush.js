/**
 * Local-notifications-only fix.
 *
 * expo-notifications' iOS mod always injects the `aps-environment` entitlement
 * and the `remote-notification` UIBackgroundMode (both for *push* from a server).
 * MedRemind only uses on-device scheduled (local) notifications, so it doesn't
 * need either — and a free Apple Developer (personal) team can't sign an app
 * that requests Push Notifications, which fails the device build.
 *
 * This plugin runs after expo-notifications and strips both, so personal-team
 * device builds succeed while local reminders keep working.
 */
const { withEntitlementsPlist, withInfoPlist } = require('expo/config-plugins');

const withoutRemotePush = (config) => {
  config = withEntitlementsPlist(config, (cfg) => {
    delete cfg.modResults['aps-environment'];
    return cfg;
  });

  config = withInfoPlist(config, (cfg) => {
    const modes = cfg.modResults.UIBackgroundModes;
    if (Array.isArray(modes)) {
      cfg.modResults.UIBackgroundModes = modes.filter(
        (m) => m !== 'remote-notification',
      );
      if (cfg.modResults.UIBackgroundModes.length === 0) {
        delete cfg.modResults.UIBackgroundModes;
      }
    }
    return cfg;
  });

  return config;
};

module.exports = withoutRemotePush;
