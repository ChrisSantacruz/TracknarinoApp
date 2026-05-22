const path = require('path');
const mongoose = require('mongoose');
require('dotenv').config({ path: path.join(__dirname, '..', '..', '.env') });

async function connectMongo() {
  const mongoUri = process.env.MONGO_URI || 'mongodb://localhost:27017/trackarino';
  await mongoose.connect(mongoUri);
  return mongoUri;
}

module.exports = { connectMongo };
