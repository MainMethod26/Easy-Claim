with open('backend/src/index.ts', 'r') as f:
    content = f.read()

content = "import { cors } from 'hono/cors'\n" + content
content = content.replace("const app = new Hono<{ Bindings: Env }>()\n", "const app = new Hono<{ Bindings: Env }>()\napp.use('/*', cors())\n")

with open('backend/src/index.ts', 'w') as f:
    f.write(content)
