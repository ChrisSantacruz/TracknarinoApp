const assert = require('node:assert/strict');
const test = require('node:test');

const authRoutes = require('../routes/authRoutes');
const oportunidadRoutes = require('../routes/oportunidadRoutes');
const calificacionRoutes = require('../routes/calificacionRoutes');

function routeExists(router, method, path) {
  return router.stack.some((layer) => {
    const route = layer.route;
    return route?.path === path && route.methods?.[method] === true;
  });
}

test('auth routes expose login, register and profile contracts', () => {
  assert.equal(routeExists(authRoutes, 'post', '/login'), true);
  assert.equal(routeExists(authRoutes, 'post', '/register'), true);
  assert.equal(routeExists(authRoutes, 'post', '/registro'), true);
  assert.equal(routeExists(authRoutes, 'get', '/perfil'), true);
  assert.equal(routeExists(authRoutes, 'put', '/actualizar-pago'), true);
});

test('opportunity routes expose trip lifecycle and negotiation contracts', () => {
  assert.equal(routeExists(oportunidadRoutes, 'get', '/'), true);
  assert.equal(routeExists(oportunidadRoutes, 'get', '/disponibles'), true);
  assert.equal(routeExists(oportunidadRoutes, 'post', '/crear'), true);
  assert.equal(routeExists(oportunidadRoutes, 'put', '/:id/aceptar'), true);
  assert.equal(routeExists(oportunidadRoutes, 'put', '/:id/iniciar'), true);
  assert.equal(routeExists(oportunidadRoutes, 'get', '/viaje-activo'), true);
  assert.equal(routeExists(oportunidadRoutes, 'post', '/:id/oferta'), true);
  assert.equal(routeExists(oportunidadRoutes, 'delete', '/:id/oferta'), true);
  assert.equal(routeExists(oportunidadRoutes, 'post', '/:id/contraoferta'), true);
  assert.equal(routeExists(oportunidadRoutes, 'put', '/:id/contraoferta/aceptar'), true);
});

test('rating routes expose create and list contracts', () => {
  assert.equal(routeExists(calificacionRoutes, 'post', '/crear'), true);
  assert.equal(routeExists(calificacionRoutes, 'get', '/listar/:id'), true);
});
