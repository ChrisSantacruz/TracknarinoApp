const mongoose = require('mongoose');

const offerSchema = new mongoose.Schema({
  oportunidad: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Oportunidad',
    required: true,
    index: true,
  },
  camionero: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true,
  },
  owner: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true,
  },
  ownerType: {
    type: String,
    enum: ['CLIENTE', 'CONTRATISTA'],
    required: true,
  },
  precio: {
    type: Number,
    required: true,
    min: 1,
  },
  comentario: {
    type: String,
    trim: true,
    maxlength: 500,
  },
  estado: {
    type: String,
    enum: ['pendiente', 'aceptada', 'rechazada', 'retirada'],
    default: 'pendiente',
    index: true,
  },
  respondedAt: {
    type: Date,
  },
}, {
  timestamps: true,
});

offerSchema.index({ oportunidad: 1, camionero: 1, estado: 1 });
offerSchema.index({ owner: 1, estado: 1, updatedAt: -1 });

module.exports = mongoose.model('Offer', offerSchema);
