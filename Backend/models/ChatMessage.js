const mongoose = require('mongoose');

const receiptSchema = new mongoose.Schema({
  user: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
  },
  at: {
    type: Date,
    default: Date.now,
  },
}, { _id: false });

const chatMessageSchema = new mongoose.Schema({
  trip: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Oportunidad',
    required: true,
    index: true,
  },
  sender: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true,
  },
  senderRole: {
    type: String,
    enum: ['cliente', 'contratista', 'camionero'],
    required: true,
  },
  message: {
    type: String,
    required: true,
    trim: true,
    minlength: 1,
    maxlength: 2000,
  },
  deliveredTo: [receiptSchema],
  readBy: [receiptSchema],
}, {
  timestamps: true,
});

chatMessageSchema.index({ trip: 1, createdAt: -1 });

module.exports = mongoose.model('ChatMessage', chatMessageSchema);
