const mongoose = require('mongoose');
const Oportunidad = require('../models/Oportunidad');

function roleToOwnerType(role) {
  if (role === 'cliente') return 'CLIENTE';
  if (role === 'contratista') return 'CONTRATISTA';
  return null;
}

function getOwnerId(oportunidad) {
  return oportunidad.ownerId?.toString?.()
    || oportunidad.ownerId
    || oportunidad.contratista?.toString?.()
    || oportunidad.contratista
    || null;
}

function isOpportunityOwner(oportunidad, user) {
  if (!oportunidad || !user?.id) return false;
  return getOwnerId(oportunidad)?.toString() === user.id.toString();
}

function isAssignedDriver(oportunidad, user) {
  if (!oportunidad || !user?.id) return false;
  return oportunidad.camioneroAsignado?.toString?.() === user.id.toString();
}

function buildOpportunityListFilter(user, ownerType) {
  const role = user?.tipoUsuario;
  const normalizedOwnerType = String(ownerType || '').toUpperCase();

  if (role === 'cliente') {
    return {
      $or: [
        { ownerId: user.id },
        { ownerType: 'CLIENTE', createdBy: user.id },
      ],
    };
  }

  if (role === 'contratista') {
    const filter = {
      $or: [
        { ownerId: user.id },
        { contratista: user.id },
      ],
    };
    if (normalizedOwnerType === 'CLIENTE' || normalizedOwnerType === 'CONTRATISTA') {
      filter.ownerType = normalizedOwnerType;
    }
    return filter;
  }

  if (role === 'camionero') {
    const filter = {
      $or: [
        { estado: 'disponible' },
        { camioneroAsignado: user.id },
      ],
    };
    if (normalizedOwnerType === 'CLIENTE' || normalizedOwnerType === 'CONTRATISTA') {
      filter.ownerType = normalizedOwnerType;
    }
    return filter;
  }

  return { _id: null };
}

async function canAccessTrip(user, oportunidadId) {
  if (!user?.id || !mongoose.Types.ObjectId.isValid(oportunidadId)) {
    return { allowed: false, oportunidad: null };
  }

  const oportunidad = await Oportunidad.findById(oportunidadId);
  if (!oportunidad) return { allowed: false, oportunidad: null };

  const allowed = isOpportunityOwner(oportunidad, user) || isAssignedDriver(oportunidad, user);
  return { allowed, oportunidad };
}

module.exports = {
  roleToOwnerType,
  getOwnerId,
  isOpportunityOwner,
  isAssignedDriver,
  buildOpportunityListFilter,
  canAccessTrip,
};
