const express = require('express');
const verificarToken = require('../middleware/authMiddleware');
const asyncHandler = require('../middleware/asyncHandler');
const {
  saveDeliveryEvidence,
  getDeliveryEvidence,
  enableSharedTracking,
  disableSharedTracking,
  getSharedTracking,
  rateTrip,
} = require('../controllers/tripExtrasController');

const router = express.Router();

router.get('/tracking/shared/:trackingId', asyncHandler(getSharedTracking));
router.post('/trips/:tripId/delivery-evidence', verificarToken, asyncHandler(saveDeliveryEvidence));
router.get('/trips/:tripId/delivery-evidence', verificarToken, asyncHandler(getDeliveryEvidence));
router.post('/trips/:tripId/share', verificarToken, asyncHandler(enableSharedTracking));
router.delete('/trips/:tripId/share', verificarToken, asyncHandler(disableSharedTracking));
router.post('/trips/:tripId/ratings', verificarToken, asyncHandler(rateTrip));

module.exports = router;
