CREATE TABLE IF NOT EXISTS policies (
    id TEXT PRIMARY KEY,
    user_id TEXT,
    plan_name TEXT,
    status TEXT
);
CREATE TABLE IF NOT EXISTS claims (
    id TEXT PRIMARY KEY,
    user_id TEXT,
    policy_id TEXT,
    stage TEXT,
    status TEXT
);
