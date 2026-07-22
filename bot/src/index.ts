import 'discord.js';
import { Events } from 'discord.js';
import { client } from './client.js';
import { initDb } from './db/index.js';
import { registerCommands, commandHandlers } from './commands/registry.js';
import { handleButton } from './handlers/buttons.js';
import { handleModal } from './handlers/modals.js';
import { log } from './utils/log.js';
import { startServer } from './server.js';

async function main() {
  await initDb();

  const port = parseInt(process.env.PORT ?? '3000', 10);
  startServer(port);

  client.once(Events.ClientReady, async (c) => {
    log.info(`Bot online sebagai ${c.user.tag}`);
    await registerCommands();
  });

  client.on(Events.InteractionCreate, async (interaction) => {
    // Patch deferReply so that if another bot instance already acknowledged
    // this interaction (code 40060), we silently continue instead of throwing.
    // This lets Replit recover a hanging Railway instance and still send editReply.
    if ('deferReply' in interaction && typeof (interaction as any).deferReply === 'function') {
      const _orig = (interaction as any).deferReply.bind(interaction);
      (interaction as any).deferReply = async (opts?: unknown) => {
        try {
          return await _orig(opts);
        } catch (e: any) {
          if (e?.code === 40060) {
            // Already acknowledged by another instance — mark as deferred locally
            Object.defineProperty(interaction, 'deferred', { value: true, writable: true });
            return;
          }
          throw e;
        }
      };
    }

    try {
      if (interaction.isChatInputCommand()) {
        const handler = commandHandlers.get(interaction.commandName);
        if (handler) await handler(interaction);
      } else if (interaction.isButton()) {
        await handleButton(interaction);
      } else if (interaction.isModalSubmit()) {
        await handleModal(interaction);
      }
    } catch (err) {
      log.error({ err }, 'Interaction error');
      if (interaction.isRepliable() && !interaction.replied && !interaction.deferred) {
        await interaction.reply({
          content: '❌ Terjadi kesalahan internal. Coba lagi nanti.',
          ephemeral: true,
        }).catch(() => {});
      }
    }
  });

  await client.login(process.env.DISCORD_BOT_TOKEN);
}

main().catch((err) => {
  log.error({ err }, 'Fatal error');
  process.exit(1);
});
