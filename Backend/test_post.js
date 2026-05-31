const axios = require('axios');

async function test() {
  try {
    const res = await axios.post('http://localhost:4000/api/auth/register', {
      nombre: 'UsuarioNodeTest',
      correo: 'node+test@example.com',
      contraseña: '123456',
      tipoUsuario: 'usuario'
    }, { timeout: 5000 });

    console.log('STATUS:', res.status);
    console.log('DATA:', res.data);
  } catch (err) {
    if (err.response) {
      console.error('STATUS:', err.response.status);
      console.error('DATA:', err.response.data);
    } else {
      console.error('ERROR:', err.message);
    }
  }
}

test();
