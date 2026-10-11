-- =====================================================================================
-- Demo Database Schema: Modern Multi-Tenant Cloud SaaS Platform
-- Target RDBMS: PostgreSQL 13+
-- Description: Sector-neutral, enterprise-grade architecture demonstrating schemas,
--              primary keys, foreign keys, unique constraints, jsonb, and relations.
-- Compatible with: DER-Viewer (scripts/extract-pg-der.ps1 & scripts/extract-pg-der.sh)
-- =====================================================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- -------------------------------------------------------------------------------------
-- 1. SCHEMAS
-- -------------------------------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS auth;
CREATE SCHEMA IF NOT EXISTS tenants;
CREATE SCHEMA IF NOT EXISTS billing;
CREATE SCHEMA IF NOT EXISTS projects;
CREATE SCHEMA IF NOT EXISTS audit;

-- -------------------------------------------------------------------------------------
-- 2. SCHEMA: AUTH (Identity, RBAC & Sessions)
-- -------------------------------------------------------------------------------------

CREATE TABLE auth.users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(150) NOT NULL,
    email_verified BOOLEAN NOT NULL DEFAULT FALSE,
    status VARCHAR(50) NOT NULL DEFAULT 'ACTIVE',
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE auth.roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    description TEXT
);

CREATE TABLE auth.permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(100) NOT NULL UNIQUE,
    module VARCHAR(50) NOT NULL,
    description TEXT
);

CREATE TABLE auth.role_permissions (
    role_id UUID NOT NULL REFERENCES auth.roles(id) ON DELETE CASCADE,
    permission_id UUID NOT NULL REFERENCES auth.permissions(id) ON DELETE CASCADE,
    PRIMARY KEY (role_id, permission_id)
);

CREATE TABLE auth.user_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    token_hash VARCHAR(255) NOT NULL UNIQUE,
    ip_address VARCHAR(45),
    user_agent VARCHAR(500),
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- -------------------------------------------------------------------------------------
-- 3. SCHEMA: TENANTS (Multi-tenant Organizations, Teams & Memberships)
-- -------------------------------------------------------------------------------------

CREATE TABLE tenants.organization (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slug VARCHAR(63) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    plan_tier VARCHAR(50) NOT NULL DEFAULT 'STARTER',
    owner_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
    settings JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE tenants.membership (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES tenants.organization(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    role_id UUID NOT NULL REFERENCES auth.roles(id) ON DELETE RESTRICT,
    status VARCHAR(50) NOT NULL DEFAULT 'ACTIVE',
    joined_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_membership_org_user UNIQUE (organization_id, user_id)
);

CREATE TABLE tenants.team (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES tenants.organization(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    description TEXT
);

CREATE TABLE tenants.team_member (
    team_id UUID NOT NULL REFERENCES tenants.team(id) ON DELETE CASCADE,
    membership_id UUID NOT NULL REFERENCES tenants.membership(id) ON DELETE CASCADE,
    PRIMARY KEY (team_id, membership_id)
);

-- -------------------------------------------------------------------------------------
-- 4. SCHEMA: BILLING (Plans, Subscriptions & Invoicing)
-- -------------------------------------------------------------------------------------

CREATE TABLE billing.plan (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    price_monthly NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    price_yearly NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    features_quota JSONB NOT NULL DEFAULT '{}'::jsonb,
    is_active BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE billing.subscription (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES tenants.organization(id) ON DELETE RESTRICT,
    plan_id UUID NOT NULL REFERENCES billing.plan(id) ON DELETE RESTRICT,
    status VARCHAR(50) NOT NULL DEFAULT 'ACTIVE',
    billing_cycle VARCHAR(20) NOT NULL DEFAULT 'MONTHLY',
    current_period_start TIMESTAMPTZ NOT NULL,
    current_period_end TIMESTAMPTZ NOT NULL,
    cancel_at TIMESTAMPTZ
);

CREATE TABLE billing.invoice (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    subscription_id UUID NOT NULL REFERENCES billing.subscription(id) ON DELETE CASCADE,
    invoice_number VARCHAR(50) NOT NULL UNIQUE,
    amount_due NUMERIC(10, 2) NOT NULL,
    amount_paid NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    currency VARCHAR(3) NOT NULL DEFAULT 'USD',
    status VARCHAR(50) NOT NULL DEFAULT 'PAID',
    issued_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    paid_at TIMESTAMPTZ
);

-- -------------------------------------------------------------------------------------
-- 5. SCHEMA: PROJECTS (Workspaces, Projects, Tasks & Tags)
-- -------------------------------------------------------------------------------------

CREATE TABLE projects.workspace (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES tenants.organization(id) ON DELETE CASCADE,
    name VARCHAR(120) NOT NULL,
    visibility VARCHAR(20) NOT NULL DEFAULT 'PRIVATE',
    created_by_membership_id UUID NOT NULL REFERENCES tenants.membership(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE projects.project (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workspace_id UUID NOT NULL REFERENCES projects.workspace(id) ON DELETE CASCADE,
    key VARCHAR(20) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'IN_PROGRESS',
    budget NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    deadline TIMESTAMPTZ
);

CREATE TABLE projects.task (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID NOT NULL REFERENCES projects.project(id) ON DELETE CASCADE,
    task_number VARCHAR(30) NOT NULL UNIQUE,
    title VARCHAR(200) NOT NULL,
    description TEXT,
    priority VARCHAR(20) NOT NULL DEFAULT 'MEDIUM',
    status VARCHAR(50) NOT NULL DEFAULT 'TODO',
    assignee_membership_id UUID REFERENCES tenants.membership(id) ON DELETE SET NULL,
    due_date TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE projects.tag (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workspace_id UUID NOT NULL REFERENCES projects.workspace(id) ON DELETE CASCADE,
    name VARCHAR(50) NOT NULL,
    color_hex VARCHAR(7) NOT NULL DEFAULT '#3B82F6',
    CONSTRAINT uq_tag_workspace_name UNIQUE (workspace_id, name)
);

CREATE TABLE projects.task_tags (
    task_id UUID NOT NULL REFERENCES projects.task(id) ON DELETE CASCADE,
    tag_id UUID NOT NULL REFERENCES projects.tag(id) ON DELETE CASCADE,
    PRIMARY KEY (task_id, tag_id)
);

-- -------------------------------------------------------------------------------------
-- 6. SCHEMA: AUDIT (Event Tracking & System Logs)
-- -------------------------------------------------------------------------------------

CREATE TABLE audit.activity_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES tenants.organization(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    event_type VARCHAR(100) NOT NULL,
    entity_type VARCHAR(100) NOT NULL,
    entity_id UUID,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    timestamp TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- -------------------------------------------------------------------------------------
-- 7. SEED DATA (Demonstrative Initial Dataset)
-- -------------------------------------------------------------------------------------

-- Roles & Permissions
INSERT INTO auth.roles (id, code, name, description) VALUES
    ('11111111-1111-1111-1111-111111111101', 'SUPER_ADMIN', 'Super Admin', 'Full control over platform resources'),
    ('11111111-1111-1111-1111-111111111102', 'ORG_OWNER', 'Organization Owner', 'Billing, tenant and team management'),
    ('11111111-1111-1111-1111-111111111103', 'MEMBER', 'Standard Member', 'General project and task collaborator');

INSERT INTO auth.permissions (id, code, module, description) VALUES
    ('22222222-2222-2222-2222-222222222201', 'org:read', 'tenants', 'View organization details'),
    ('22222222-2222-2222-2222-222222222202', 'org:update', 'tenants', 'Edit organization settings'),
    ('22222222-2222-2222-2222-222222222203', 'project:create', 'projects', 'Create new projects'),
    ('22222222-2222-2222-2222-222222222204', 'task:write', 'projects', 'Create and edit tasks');

INSERT INTO auth.role_permissions (role_id, permission_id) VALUES
    ('11111111-1111-1111-1111-111111111101', '22222222-2222-2222-2222-222222222201'),
    ('11111111-1111-1111-1111-111111111101', '22222222-2222-2222-2222-222222222202'),
    ('11111111-1111-1111-1111-111111111101', '22222222-2222-2222-2222-222222222203'),
    ('11111111-1111-1111-1111-111111111101', '22222222-2222-2222-2222-222222222204'),
    ('11111111-1111-1111-1111-111111111102', '22222222-2222-2222-2222-222222222201'),
    ('11111111-1111-1111-1111-111111111102', '22222222-2222-2222-2222-222222222202'),
    ('11111111-1111-1111-1111-111111111103', '22222222-2222-2222-2222-222222222204');

-- Plans
INSERT INTO billing.plan (id, code, name, price_monthly, price_yearly, features_quota, is_active) VALUES
    ('33333333-3333-3333-3333-333333333301', 'FREE_COMMUNITY', 'Free Community', 0.00, 0.00, '{"seats": 3, "storage_gb": 5, "projects": 5}'::jsonb, TRUE),
    ('33333333-3333-3333-3333-333333333302', 'PRO_TEAM', 'Pro Team', 29.00, 290.00, '{"seats": 25, "storage_gb": 100, "projects": 50}'::jsonb, TRUE),
    ('33333333-3333-3333-3333-333333333303', 'ENTERPRISE_UNLIMITED', 'Enterprise Unlimited', 99.00, 990.00, '{"seats": 1000, "storage_gb": 2048, "projects": 10000}'::jsonb, TRUE);

-- Users
INSERT INTO auth.users (id, email, password_hash, full_name, email_verified, status) VALUES
    ('44444444-4444-4444-4444-444444444401', 'alex.morgan@acmesoftware.io', '$2a$12$e9qO..hashSampleAlex', 'Alex Morgan', TRUE, 'ACTIVE'),
    ('44444444-4444-4444-4444-444444444402', 'dev.lead@acmesoftware.io', '$2a$12$e9qO..hashSampleLead', 'Jordan Rivera', TRUE, 'ACTIVE');

-- Tenant & Membership
INSERT INTO tenants.organization (id, slug, name, plan_tier, owner_user_id, settings) VALUES
    ('55555555-5555-5555-5555-555555555501', 'acme-corp', 'Acme Global Software', 'PRO_TEAM', '44444444-4444-4444-4444-444444444401', '{"locale": "en_US", "theme": "dark"}'::jsonb);

INSERT INTO tenants.membership (id, organization_id, user_id, role_id, status) VALUES
    ('66666666-6666-6666-6666-666666666601', '55555555-5555-5555-5555-555555555501', '44444444-4444-4444-4444-444444444401', '11111111-1111-1111-1111-111111111102', 'ACTIVE'),
    ('66666666-6666-6666-6666-666666666602', '55555555-5555-5555-5555-555555555501', '44444444-4444-4444-4444-444444444402', '11111111-1111-1111-1111-111111111103', 'ACTIVE');
