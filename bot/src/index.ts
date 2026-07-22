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
      if (!interaction.isRepliable()) return;
      if (!interaction.replied && !interaction.deferred) {
        await interaction.reply({ content: '❌ Terjadi kesalahan internal. Coba lagi nanti.', ephemeral: true }).catch(() => {});
      } else if (interaction.deferred && !interaction.replied) {
        await interaction.editReply({ content: '❌ Terjadi kesalahan internal. Coba lagi nanti.' }).catch(() => {});
      }
    }
  });

  await client.login(process.env.DISCORD_BOT_TOKEN);
}

main().catch((err) => {
  log.error({ err }, 'Fatal error');
  process.exit(1);
});
