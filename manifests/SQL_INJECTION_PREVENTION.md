# SQL Injection Prevention Guide

## ✅ Current Protection Status

### Protected Patterns Found:
1. **Parameterized Queries** - All queries use `$1, $2` placeholders
2. **AsyncPG Library** - Enforces parameterized queries
3. **Pydantic Input Validation** - Type checking on inputs
4. **Field Whitelisting** - UPDATE queries validate field names

### Vulnerabilities Fixed:
1. ~~`eval()` usage~~ → Replaced with `json.loads()`
2. ~~Dynamic field names~~ → Added field whitelist validation
3. ~~String concatenation in SQL~~ → Using proper parameterization

## 🛡️ SQL Injection Prevention Best Practices

### 1. Always Use Parameterized Queries

**✅ SAFE:**
```python
# Using numbered parameters
sql = "SELECT * FROM users WHERE email = $1 AND active = $2"
result = await conn.fetchrow(sql, email, True)

# Multiple parameters
sql = "INSERT INTO products (name, price, category) VALUES ($1, $2, $3)"
await conn.execute(sql, name, price, category)
```

**❌ UNSAFE:**
```python
# String concatenation
sql = f"SELECT * FROM users WHERE email = '{email}'"  # NEVER DO THIS!

# String formatting
sql = "SELECT * FROM users WHERE email = '%s'" % email  # NEVER DO THIS!

# f-strings with user input
sql = f"SELECT * FROM users WHERE {user_field} = '{value}'"  # NEVER DO THIS!
```

### 2. Validate Dynamic Field Names

When building dynamic queries, always validate field names against a whitelist:

```python
# Safe dynamic query building
allowed_fields = {'name', 'price', 'category', 'description'}
updates = []
params = []

for i, (field, value) in enumerate(data.items(), 1):
    if field not in allowed_fields:
        raise ValueError(f"Invalid field: {field}")
    updates.append(f"{field} = ${i}")
    params.append(value)

sql = f"UPDATE products SET {', '.join(updates)} WHERE id = ${len(params) + 1}"
params.append(product_id)
await conn.execute(sql, *params)
```

### 3. Input Validation

Use Pydantic models for strict input validation:

```python
from pydantic import BaseModel, validator, constr

class ProductSearch(BaseModel):
    category: constr(regex='^[a-zA-Z0-9_-]+$')  # Alphanumeric only
    min_price: float = Field(ge=0, le=1000000)
    max_price: float = Field(ge=0, le=1000000)
    
    @validator('category')
    def validate_category(cls, v):
        allowed_categories = {'tools', 'parts', 'accessories'}
        if v not in allowed_categories:
            raise ValueError('Invalid category')
        return v
```

### 4. Escape Special Characters

For LIKE queries, escape wildcards:

```python
def escape_like_pattern(pattern: str) -> str:
    """Escape special characters for LIKE queries"""
    return pattern.replace('\\', '\\\\').replace('%', '\\%').replace('_', '\\_')

# Safe LIKE query
search_term = escape_like_pattern(user_input)
sql = "SELECT * FROM products WHERE name LIKE $1"
await conn.fetch(sql, f"%{search_term}%")
```

### 5. Use Database Permissions

Limit database user permissions:

```sql
-- Create read-only user for queries
CREATE USER app_readonly WITH PASSWORD 'strong_password';
GRANT SELECT ON ALL TABLES IN SCHEMA public TO app_readonly;

-- Create limited write user
CREATE USER app_writer WITH PASSWORD 'strong_password';
GRANT SELECT, INSERT, UPDATE, DELETE ON products, orders TO app_writer;
-- Never grant CREATE, DROP, ALTER permissions to app users
```

### 6. Stored Procedures (When Appropriate)

For complex operations, use stored procedures:

```sql
CREATE OR REPLACE FUNCTION search_products(
    p_category TEXT,
    p_min_price NUMERIC,
    p_max_price NUMERIC
) RETURNS TABLE(...) AS $$
BEGIN
    RETURN QUERY
    SELECT * FROM products
    WHERE category = p_category
    AND price BETWEEN p_min_price AND p_max_price;
END;
$$ LANGUAGE plpgsql;
```

### 7. Audit and Logging

Log all database queries in development:

```python
import logging

async def execute_query(conn, sql, *params):
    logger.debug(f"Executing SQL: {sql}")
    logger.debug(f"Parameters: {params}")
    try:
        result = await conn.execute(sql, *params)
        logger.debug(f"Query successful")
        return result
    except Exception as e:
        logger.error(f"Query failed: {e}")
        raise
```

## 🔍 Security Checklist

Before deploying, ensure:

- [ ] No string concatenation in SQL queries
- [ ] All user inputs are parameterized
- [ ] Dynamic field names are whitelisted
- [ ] No `eval()` or `exec()` on user input
- [ ] Input validation using Pydantic models
- [ ] Database users have minimal permissions
- [ ] SQL query logging enabled (dev only)
- [ ] Regular security audits scheduled

## 🚨 Common Mistakes to Avoid

1. **Using f-strings for SQL**
   ```python
   # NEVER do this
   sql = f"SELECT * FROM users WHERE id = {user_id}"
   ```

2. **Trusting client-side validation**
   - Always validate on server side
   - Never trust user input

3. **Using dynamic table/column names**
   ```python
   # DANGEROUS
   sql = f"SELECT * FROM {table_name}"  # SQL injection risk!
   ```

4. **Forgetting about second-order injection**
   - Data from database can also be malicious
   - Parameterize even when using stored data

5. **Not escaping LIKE patterns**
   - `%` and `_` are wildcards in LIKE queries
   - Always escape user input for LIKE

## 🔧 Testing for SQL Injection

Test your application with these payloads (in a safe environment):

```python
test_inputs = [
    "'; DROP TABLE users; --",
    "1' OR '1'='1",
    "admin'--",
    "1; SELECT * FROM users WHERE 't' = 't",
    "' UNION SELECT NULL, NULL, NULL--",
    "1' AND SLEEP(5)--",
]
```

## 📚 Additional Resources

- [OWASP SQL Injection Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html)
- [AsyncPG Documentation](https://magicstack.github.io/asyncpg/current/)
- [PostgreSQL Security Best Practices](https://www.postgresql.org/docs/current/sql-createuser.html)

Remember: **Always assume user input is malicious!**