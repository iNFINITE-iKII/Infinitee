import {
  REST,
  Routes,
  SlashCommandBuilder,
  SlashCommandSubcommandBuilder,
} from 'discord.js';
import { log } from '../utils/log.js';

export const commandHandlers = new Map<string, (i: any) => Promise<void>>();

export function registerHandler(name: string, handler: (i: any) => Promise<void>) {
  commandHandlers.set(name, handler);
}

export async function registerCommands() {
  const { genkey, GENKEY_DEF } = await import('./genkey.js');
  const { checkkey, CHECKKEY_DEF } = await import('./checkkey.js');
  const { revoke, REVOKE_DEF } = await import('./revoke.js');
  const { deletekey, DELETEKEY_DEF } = await import('./deletekey.js');
  const { renewkey, RENEWKEY_DEF } = await import('./renewkey.js');
  const { setlabel, SETLABEL_DEF } = await import('./setlabel.js');
  const { cleanup, CLEANUP_DEF } = await import('./cleanup.js');
  const { sethwid, SETHWID_DEF } = await import('./sethwid.js');
  const { resethwid, RESETHWID_DEF } = await import('./resethwid.js');
  const { setmaxhwid, SETMAXHWID_DEF } = await import('./setmaxhwid.js');
  const { setaccountlimit, SETACCOUNTLIMIT_DEF } = await import('./setaccountlimit.js');
  const { handleWhitelist, WHITELIST_DEF } = await import('./whitelist.js');
  const { userkey, USERKEY_DEF } = await import('./userkey.js');
  const { stats, STATS_DEF } = await import('./stats.js');
  const { transferkey, TRANSFERKEY_DEF } = await import('./transferkey.js');
  const { syncpremium, SYNCPREMIUM_DEF } = await import('./syncpremium.js');
  const { panel, PANEL_DEF } = await import('./panel.js');
  const { resetticket, RESETTICKET_DEF } = await import('./resetticket.js');
  const { help, HELP_DEF } = await import('./help.js');

  registerHandler('genkey', genkey);
  registerHandler('checkkey', checkkey);
  registerHandler('revoke', revoke);
  registerHandler('deletekey', deletekey);
  registerHandler('renewkey', renewkey);
  registerHandler('setlabel', setlabel);
  registerHandler('cleanup', cleanup);
  registerHandler('sethwid', sethwid);
  registerHandler('resethwid', resethwid);
  registerHandler('setmaxhwid', setmaxhwid);
  registerHandler('setaccountlimit', setaccountlimit);
  registerHandler('whitelist', handleWhitelist);
  registerHandler('userkey', userkey);
  registerHandler('stats', stats);
  registerHandler('transferkey', transferkey);
  registerHandler('syncpremium', syncpremium);
  registerHandler('panel', panel);
  registerHandler('resetticket', resetticket);
  registerHandler('help', help);

  const defs = [
    GENKEY_DEF, CHECKKEY_DEF, REVOKE_DEF, DELETEKEY_DEF, RENEWKEY_DEF,
    SETLABEL_DEF, CLEANUP_DEF, SETHWID_DEF, RESETHWID_DEF, SETMAXHWID_DEF,
    SETACCOUNTLIMIT_DEF, WHITELIST_DEF, USERKEY_DEF, STATS_DEF,
    TRANSFERKEY_DEF, SYNCPREMIUM_DEF, PANEL_DEF, RESETTICKET_DEF, HELP_DEF,
  ];

  const rest = new REST().setToken(process.env.DISCORD_BOT_TOKEN!);
  await rest.put(
    Routes.applicationGuildCommands(
      process.env.DISCORD_CLIENT_ID!,
      process.env.DISCORD_GUILD_ID!,
    ),
    { body: defs.map((d) => d.toJSON()) },
  );
  log.info(`Registered ${defs.length} slash commands`);
}
