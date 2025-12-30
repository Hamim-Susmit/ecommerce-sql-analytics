"""
E-COMMERCE ANALYTICS: Python + PostgreSQL Integration
Author: Your Name
Purpose: Connect Python to PostgreSQL for advanced analysis and visualization
"""

import pandas as pd
import numpy as np
from sqlalchemy import create_engine, text
import matplotlib.pyplot as plt
import seaborn as sns
from datetime import datetime
import warnings
warnings.filterwarnings('ignore')

# Set visualization defaults
plt.style.use('seaborn-v0_8-darkgrid')
sns.set_palette("husl")
plt.rcParams['figure.figsize'] = (12, 6)
plt.rcParams['font.size'] = 10

# =====================================================
# DATABASE CONNECTION
# =====================================================

class EcommerceDB:
    """
    Database connection manager for e-commerce analytics.
    
    Best Practices:
    - Use connection pooling for performance
    - Close connections after use
    - Use parameterized queries to prevent SQL injection
    - Store credentials securely (environment variables)
    """
    
    def __init__(self, host='localhost', port=5432, database='ecommerce', 
                 user='postgres', password='your_password'):
        """
        Initialize database connection.
        
        In production, use environment variables:
        import os
        user = os.getenv('DB_USER')
        password = os.getenv('DB_PASSWORD')
        """
        self.connection_string = f'postgresql://{user}:{password}@{host}:{port}/{database}'
        self.engine = None
        
    def connect(self):
        """Establish database connection."""
        try:
            self.engine = create_engine(self.connection_string)
            print(f"✓ Connected to database successfully")
            return self.engine
        except Exception as e:
            print(f"✗ Connection failed: {e}")
            return None
    
    def test_connection(self):
        """Test database connection with a simple query."""
        if self.engine is None:
            print("✗ No engine. Call connect() first.")
            return False
        
        try:
            with self.engine.connect() as conn:
                result = conn.execute(text("SELECT version();"))
                version = result.fetchone()[0]
                print(f"✓ Database version: {version}")
                return True
        except Exception as e:
            print(f"✗ Connection test failed: {e}")
            return False
    
    def query_to_dataframe(self, query, params=None):
        """
        Execute SQL query and return pandas DataFrame.
        
        Args:
            query (str): SQL query
            params (dict): Optional query parameters
        
        Returns:
            pd.DataFrame: Query results
        """
        try:
            if params:
                df = pd.read_sql_query(text(query), self.engine, params=params)
            else:
                df = pd.read_sql_query(query, self.engine)
            print(f"✓ Query executed: {len(df)} rows returned")
            return df
        except Exception as e:
            print(f"✗ Query failed: {e}")
            return None
    
    def close(self):
        """Close database connection."""
        if self.engine:
            self.engine.dispose()
            print("✓ Database connection closed")


# =====================================================
# ANALYSIS FUNCTIONS
# =====================================================

def load_revenue_trends(db):
    """Load monthly revenue trends from database."""
    query = """
    SELECT 
        DATE_TRUNC('month', o.order_purchase_timestamp) as order_month,
        COUNT(DISTINCT o.order_id) as orders,
        ROUND(SUM(oi.price + oi.freight_value)::numeric, 2) as revenue,
        ROUND(AVG(oi.price + oi.freight_value)::numeric, 2) as avg_order_value
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY DATE_TRUNC('month', o.order_purchase_timestamp)
    ORDER BY order_month;
    """
    
    df = db.query_to_dataframe(query)
    if df is not None:
        df['order_month'] = pd.to_datetime(df['order_month'])
        df['revenue'] = df['revenue'].astype(float)
    return df


def load_customer_metrics(db):
    """Load customer behavior metrics."""
    query = """
    WITH customer_summary AS (
        SELECT 
            c.customer_unique_id,
            c.customer_state,
            COUNT(DISTINCT o.order_id) as total_orders,
            ROUND(SUM(oi.price + oi.freight_value)::numeric, 2) as lifetime_value,
            MIN(o.order_purchase_timestamp) as first_purchase,
            MAX(o.order_purchase_timestamp) as last_purchase
        FROM customers c
        JOIN orders o ON c.customer_id = o.customer_id
        JOIN order_items oi ON o.order_id = oi.order_id
        WHERE o.order_status = 'delivered'
        GROUP BY c.customer_unique_id, c.customer_state
    )
    SELECT 
        *,
        EXTRACT(DAY FROM (last_purchase - first_purchase)) as customer_age_days
    FROM customer_summary;
    """
    
    df = db.query_to_dataframe(query)
    if df is not None:
        df['lifetime_value'] = df['lifetime_value'].astype(float)
        df['first_purchase'] = pd.to_datetime(df['first_purchase'])
        df['last_purchase'] = pd.to_datetime(df['last_purchase'])
    return df


def load_cohort_data(db):
    """Load cohort retention data."""
    query = """
    WITH cohort_activity AS (
        SELECT 
            DATE_TRUNC('month', cfp.first_purchase) as cohort_month,
            EXTRACT(YEAR FROM AGE(o.order_purchase_timestamp, cfp.first_purchase)) * 12 +
            EXTRACT(MONTH FROM AGE(o.order_purchase_timestamp, cfp.first_purchase)) as months_since_first,
            COUNT(DISTINCT c.customer_unique_id) as active_customers
        FROM customers c
        JOIN orders o ON c.customer_id = o.customer_id
        JOIN (
            SELECT 
                c.customer_unique_id,
                MIN(o.order_purchase_timestamp) as first_purchase
            FROM customers c
            JOIN orders o ON c.customer_id = o.customer_id
            WHERE o.order_status = 'delivered'
            GROUP BY c.customer_unique_id
        ) cfp ON c.customer_unique_id = cfp.customer_unique_id
        WHERE o.order_status = 'delivered'
        GROUP BY 
            DATE_TRUNC('month', cfp.first_purchase),
            EXTRACT(YEAR FROM AGE(o.order_purchase_timestamp, cfp.first_purchase)) * 12 +
            EXTRACT(MONTH FROM AGE(o.order_purchase_timestamp, cfp.first_purchase))
    ),
    cohort_sizes AS (
        SELECT 
            DATE_TRUNC('month', MIN(o.order_purchase_timestamp)) as cohort_month,
            COUNT(DISTINCT c.customer_unique_id) as cohort_size
        FROM customers c
        JOIN orders o ON c.customer_id = o.customer_id
        WHERE o.order_status = 'delivered'
        GROUP BY c.customer_unique_id
    )
    SELECT 
        ca.cohort_month,
        cs.cohort_size,
        ca.months_since_first,
        ca.active_customers,
        ROUND(100.0 * ca.active_customers / cs.cohort_size, 2) as retention_pct
    FROM cohort_activity ca
    JOIN cohort_sizes cs ON ca.cohort_month = DATE_TRUNC('month', cs.cohort_month)
    WHERE cs.cohort_size >= 50
    ORDER BY ca.cohort_month, ca.months_since_first;
    """
    
    df = db.query_to_dataframe(query)
    if df is not None:
        df['cohort_month'] = pd.to_datetime(df['cohort_month'])
        df['retention_pct'] = df['retention_pct'].astype(float)
    return df


def load_product_performance(db):
    """Load product category performance."""
    query = """
    SELECT 
        p.product_category,
        COUNT(DISTINCT oi.order_id) as total_orders,
        ROUND(SUM(oi.price + oi.freight_value)::numeric, 2) as total_revenue,
        ROUND(AVG(oi.price + oi.freight_value)::numeric, 2) as avg_order_value,
        COUNT(DISTINCT oi.product_id) as unique_products
    FROM order_items oi
    JOIN products p ON oi.product_id = p.product_id
    JOIN orders o ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
        AND p.product_category IS NOT NULL
    GROUP BY p.product_category
    HAVING COUNT(DISTINCT oi.order_id) >= 100
    ORDER BY total_revenue DESC
    LIMIT 20;
    """
    
    df = db.query_to_dataframe(query)
    if df is not None:
        df['total_revenue'] = df['total_revenue'].astype(float)
        df['avg_order_value'] = df['avg_order_value'].astype(float)
    return df


# =====================================================
# DATA QUALITY CHECKS
# =====================================================

def check_data_quality(df, df_name="DataFrame"):
    """
    Perform comprehensive data quality checks.
    
    Args:
        df (pd.DataFrame): DataFrame to check
        df_name (str): Name for reporting
    """
    print(f"\n{'='*60}")
    print(f"DATA QUALITY REPORT: {df_name}")
    print(f"{'='*60}")
    
    print(f"\n1. BASIC INFO:")
    print(f"   Rows: {len(df):,}")
    print(f"   Columns: {len(df.columns)}")
    print(f"   Memory: {df.memory_usage(deep=True).sum() / 1024**2:.2f} MB")
    
    print(f"\n2. MISSING VALUES:")
    missing = df.isnull().sum()
    if missing.sum() > 0:
        missing_pct = 100 * missing / len(df)
        missing_report = pd.DataFrame({
            'Missing': missing[missing > 0],
            'Percent': missing_pct[missing > 0]
        }).sort_values('Missing', ascending=False)
        print(missing_report)
    else:
        print("   ✓ No missing values")
    
    print(f"\n3. DUPLICATES:")
    dup_count = df.duplicated().sum()
    print(f"   Duplicate rows: {dup_count} ({100*dup_count/len(df):.2f}%)")
    
    print(f"\n4. DATA TYPES:")
    print(df.dtypes)
    
    print(f"\n5. NUMERIC SUMMARY:")
    numeric_cols = df.select_dtypes(include=[np.number]).columns
    if len(numeric_cols) > 0:
        print(df[numeric_cols].describe())
    
    print(f"\n{'='*60}\n")


# =====================================================
# EXAMPLE USAGE
# =====================================================

def main():
    """
    Main execution function demonstrating database connection and analysis.
    """
    print("="*60)
    print("E-COMMERCE ANALYTICS: Python + SQL Integration")
    print("="*60)
    
    # Initialize database connection
    # IMPORTANT: Update with your actual credentials
    db = EcommerceDB(
        host='localhost',
        port=5432,
        database='olist_ecommerce',
        user='postgres',
        password='your_password'
    )
    
    # Connect to database
    engine = db.connect()
    if engine is None:
        print("Failed to connect. Check credentials and try again.")
        return
    
    # Test connection
    db.test_connection()
    
    # Load data
    print("\n" + "="*60)
    print("LOADING DATA FROM DATABASE")
    print("="*60)
    
    print("\n1. Revenue Trends:")
    revenue_df = load_revenue_trends(db)
    if revenue_df is not None:
        print(revenue_df.head())
        check_data_quality(revenue_df, "Revenue Trends")
    
    print("\n2. Customer Metrics:")
    customer_df = load_customer_metrics(db)
    if customer_df is not None:
        print(customer_df.head())
        print(f"\nQuick Stats:")
        print(f"   Total Customers: {len(customer_df):,}")
        print(f"   Avg Orders/Customer: {customer_df['total_orders'].mean():.2f}")
        print(f"   Avg LTV: ${customer_df['lifetime_value'].mean():.2f}")
    
    print("\n3. Cohort Data:")
    cohort_df = load_cohort_data(db)
    if cohort_df is not None:
        print(cohort_df.head(10))
    
    print("\n4. Product Performance:")
    product_df = load_product_performance(db)
    if product_df is not None:
        print(product_df.head(10))
    
    # Close connection
    db.close()
    
    print("\n" + "="*60)
    print("ANALYSIS COMPLETE")
    print("="*60)
    print("\nNext Steps:")
    print("1. Create visualizations (see 07_Visualizations.py)")
    print("2. Perform statistical analysis")
    print("3. Build predictive models")
    print("4. Export insights to dashboard")


if __name__ == "__main__":
    main()


"""
BEST PRACTICES SUMMARY:

1. CONNECTION MANAGEMENT
   ✓ Use SQLAlchemy for database abstraction
   ✓ Close connections when done
   ✓ Use connection pooling for multiple queries
   ✓ Store credentials in environment variables

2. DATA LOADING
   ✓ Use pandas for easy manipulation
   ✓ Specify data types explicitly
   ✓ Convert dates to datetime objects
   ✓ Check data quality immediately after loading

3. ERROR HANDLING
   ✓ Use try-except blocks
   ✓ Provide informative error messages
   ✓ Validate data before analysis
   ✓ Log errors for debugging

4. PERFORMANCE
   ✓ Limit data when exploring (LIMIT clause)
   ✓ Use indexes in database
   ✓ Aggregate in SQL, not Python when possible
   ✓ Monitor memory usage

5. SECURITY
   ✓ Never hardcode passwords
   ✓ Use parameterized queries
   ✓ Limit database user permissions
   ✓ Sanitize inputs

COMMON PITFALLS TO AVOID:
✗ Loading entire database into memory
✗ Not closing database connections
✗ Using string concatenation for SQL (SQL injection risk)
✗ Not handling NULL values
✗ Forgetting to convert data types
"""