function soloRol(rol) {
  return (req, res, next) => {
    const rolUsuario = req.usuario?.tipoUsuario;
    
    if (!rolUsuario) {
      return res.status(403).json({ 
        mensaje: 'Acceso denegado: Rol no encontrado en token'
      });
    }
    
    // Si se pasa un array de roles, verificar si el usuario tiene alguno de ellos
    if (Array.isArray(rol)) {
      if (!rol.includes(rolUsuario)) {
        return res.status(403).json({ 
          mensaje: 'Acceso denegado: Rol insuficiente',
          rolesPermitidos: rol,
          rolActual: rolUsuario
        });
      }
    } else {
      // Si se pasa un solo rol, verificar si el usuario lo tiene
      if (rolUsuario !== rol) {
        return res.status(403).json({ 
          mensaje: 'Acceso denegado: Rol insuficiente',
          rolRequerido: rol,
          rolActual: rolUsuario
        });
      }
    }
    
    next();
  };
}

module.exports = soloRol;
