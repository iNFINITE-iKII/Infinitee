import { EmbedBuilder, TextChannel } from 'discord.js';
import { client } from '../client.js';
import { log } from './log.js';

export async function sendLog(embed: EmbedBuilder): Promise<void> {
  const channelId = process.env.LOGGER_CHANNEL_ID;
  if (!channelId) return;
  try {
    const channel = await client.channels.fetch(channelId);
    if (channel instanceof TextChannel) {
      await channel.send({ embeds: [embed] });
    }
  } catch (err) {
    log.error({ err }, 'Failed to send log to Discord');
  }
}

export function logEmbed(title: string, color: number = 0x3498db): EmbedBuilder {
  return new EmbedBuilder()
    .setColor(color)
    .setTitle(title)
    .setTimestamp();
}
