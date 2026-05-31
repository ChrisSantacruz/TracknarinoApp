const express = require('express');
const verificarToken = require('../middleware/authMiddleware');
const asyncHandler = require('../middleware/asyncHandler');
const {
  listChatMessages,
  createChatMessage,
  markChatRead,
} = require('../controllers/chatController');

const router = express.Router();

router.get('/trips/:tripId/chat', verificarToken, asyncHandler(listChatMessages));
router.post('/trips/:tripId/chat', verificarToken, asyncHandler(createChatMessage));
router.put('/trips/:tripId/chat/read', verificarToken, asyncHandler(markChatRead));

module.exports = router;
