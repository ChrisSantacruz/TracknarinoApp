const mongoose = require('mongoose');

const ratingSchema = new mongoose.Schema({
  trip: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Oportunidad',
    required: true,
    index: true,
  },
  rater: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true,
  },
  ratedUser: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true,
  },
  raterRole: {
    type: String,
    enum: ['cliente', 'contratista', 'camionero'],
    required: true,
  },
  ratedRole: {
    type: String,
    enum: ['cliente', 'contratista', 'camionero'],
    required: true,
  },
  stars: {
    type: Number,
    min: 1,
    max: 5,
    required: true,
  },
  comment: {
    type: String,
    trim: true,
    maxlength: 1000,
  },
}, {
  timestamps: true,
  collection: 'ratings',
});

ratingSchema.index({ trip: 1, rater: 1, ratedUser: 1 }, { unique: true });

module.exports = mongoose.model('Rating', ratingSchema);
