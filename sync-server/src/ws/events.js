'use strict';

const WS_EVENTS = Object.freeze({
  // Client → Server
  JOIN: 'join',
  LEAVE: 'leave',
  PING: 'ping',

  // Server → Client
  PONG: 'pong',
  WELCOME: 'welcome',
  ERROR: 'error',

  // Project broadcast (Server → Client)
  TASK_CREATED: 'task_created',
  TASK_UPDATED: 'task_updated',
  TASK_DELETED: 'task_deleted',
  PROJECT_UPDATED: 'project_updated',
  PROJECT_DELETED: 'project_deleted',
  MEMBER_ADDED: 'member_added',
  MEMBER_UPDATED: 'member_updated',
  MEMBER_REMOVED: 'member_removed',
  NOTE_UPDATED: 'note_updated',
  MESSAGE_CREATED: 'message_created',
});

module.exports = { WS_EVENTS };
