const { WebSocket } = require('ws');

/**
 * Sends a JSON event to all WS clients subscribed to a given projectId.
 * @param {import('ws').WebSocketServer|undefined} wss
 * @param {number|string} projectId
 * @param {object} payload  Must be JSON-serialisable.
 */
function broadcastToProject(wss, projectId, payload) {
  if (!wss) return;
  const data = JSON.stringify(payload);
  wss.clients.forEach((client) => {
    if (
      client.readyState === WebSocket.OPEN &&
      String(client.projectId) === String(projectId)
    ) {
      client.send(data);
    }
  });
}

module.exports = { broadcastToProject };
