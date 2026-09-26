import re

# identityRoutes.ts
with open('backend/src/routes/identityRoutes.ts', 'r') as f:
    routes = f.read()
routes = routes.replace("router.post('/login', IdentityController.login);", "router.post('/login', IdentityController.login);\nrouter.post('/register', IdentityController.register);")
with open('backend/src/routes/identityRoutes.ts', 'w') as f:
    f.write(routes)

# identityController.ts
with open('backend/src/controllers/identityController.ts', 'r') as f:
    controller = f.read()
register_method = """
  static async register(c: Context) {
    const body = await c.req.json().catch(() => ({}));
    const result = await IdentityService.register(c.env.DB, body);
    
    if (result) {
      return c.json(result);
    }
    return c.json({ status: 'error', message: 'ID number or email already exists' }, 400);
  }
}"""
controller = controller.replace("}\n", register_method)
with open('backend/src/controllers/identityController.ts', 'w') as f:
    f.write(controller)

# identityService.ts
with open('backend/src/services/identityService.ts', 'r') as f:
    service = f.read()
register_impl = """
  static async register(db: any, data: any) {
    const { results } = await db.prepare('SELECT * FROM users WHERE id_number = ? OR email = ?').bind(data.idNumber, data.email).all();
    if (results.length > 0) return null; // already exists
    
    const id = 'usr_' + Date.now();
    await db.prepare('INSERT INTO users (id, tenant_id, role, id_number, first_name, last_name, email, phone, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)')
      .bind(id, 'tenant_sa_1', 'CUSTOMER', data.idNumber, data.firstName, data.lastName, data.email, data.phone)
      .run();
      
    return this.login(db, data.idNumber);
  }
}"""
service = service.replace("}\n", register_impl)
with open('backend/src/services/identityService.ts', 'w') as f:
    f.write(service)

