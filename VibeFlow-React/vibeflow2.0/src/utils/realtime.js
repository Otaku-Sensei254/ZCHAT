import { Socket } from "phoenix";

let socket = null;
const channels = {};

export function connectSocket(token) {
  if (socket) return;
  socket = new Socket("/socket", { params: { token }, heartbeatIntervalMs: 15000 });
  socket.connect();
}

export function disconnectSocket() {
  Object.keys(channels).forEach((t) => {
    try { channels[t].leave(); } catch {}
  });
  Object.keys(channels).forEach((t) => delete channels[t]);
  if (socket) {
    try { socket.disconnect(); } catch {}
    socket = null;
  }
}

export function joinChannel(topic, callbacks = {}) {
  if (!socket || channels[topic]) return;
  const channel = socket.channel(topic);
  Object.entries(callbacks).forEach(([event, handler]) => {
    channel.on(event, handler);
  });
  channel.join();
  channels[topic] = channel;
}

export function leaveChannel(topic) {
  if (!channels[topic]) return;
  try { channels[topic].leave(); } catch {}
  delete channels[topic];
}

export function onChannel(topic, event, handler) {
  if (channels[topic]) {
    channels[topic].on(event, handler);
  }
}

export function getSocket() {
  return socket;
}