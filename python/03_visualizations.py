"""
E-COMMERCE ANALYTICS: Professional Visualizations
Author: Your Name
Purpose: Create business-ready charts and insights
"""

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from datetime import datetime
import warnings
warnings.filterwarnings('ignore')

# Professional styling
plt.style.use('seaborn-v0_8-whitegrid')
sns.set_context("notebook", font_scale=1.1)
sns.set_palette("Set2")

# =====================================================
# 1. REVENUE TREND VISUALIZATION
# =====================================================

def plot_revenue_trends(revenue_df):
    """
    Create comprehensive revenue trend visualization.
    
    Shows: Monthly revenue, orders, and growth rates
    """
    fig, axes = plt.subplots(2, 2, figsize=(16, 10))
    fig.suptitle('Revenue Performance Dashboard', fontsize=16, fontweight='bold')
    
    # Calculate MoM growth
    revenue_df['revenue_growth'] = revenue_df['revenue'].pct_change() * 100
    revenue_df['orders_growth'] = revenue_df['orders'].pct_change() * 100
    
    # 1. Revenue Trend
    ax1 = axes[0, 0]
    ax1.plot(revenue_df['order_month'], revenue_df['revenue'], 
             marker='o', linewidth=2, markersize=6, color='#2E86AB')
    ax1.fill_between(revenue_df['order_month'], revenue_df['revenue'], 
                     alpha=0.3, color='#2E86AB')
    ax1.set_title('Monthly Revenue Trend', fontsize=12, fontweight='bold')
    ax1.set_xlabel('Month')
    ax1.set_ylabel('Revenue ($)')
    ax1.grid(True, alpha=0.3)
    ax1.tick_params(axis='x', rotation=45)
    
    # Add trend line
    z = np.polyfit(range(len(revenue_df)), revenue_df['revenue'], 1)
    p = np.poly1d(z)
    ax1.plot(revenue_df['order_month'], p(range(len(revenue_df))), 
             "--", color='red', alpha=0.8, label='Trend')
    ax1.legend()
    
    # 2. Order Volume
    ax2 = axes[0, 1]
    ax2.bar(revenue_df['order_month'], revenue_df['orders'], 
            color='#A23B72', alpha=0.7)
    ax2.set_title('Monthly Order Volume', fontsize=12, fontweight='bold')
    ax2.set_xlabel('Month')
    ax2.set_ylabel('Number of Orders')
    ax2.tick_params(axis='x', rotation=45)
    ax2.grid(True, alpha=0.3, axis='y')
    
    # 3. Revenue Growth Rate
    ax3 = axes[1, 0]
    colors = ['green' if x >= 0 else 'red' for x in revenue_df['revenue_growth']]
    ax3.bar(revenue_df['order_month'], revenue_df['revenue_growth'], 
            color=colors, alpha=0.7)
    ax3.axhline(y=0, color='black', linestyle='-', linewidth=0.5)
    ax3.set_title('Month-over-Month Revenue Growth (%)', fontsize=12, fontweight='bold')
    ax3.set_xlabel('Month')
    ax3.set_ylabel('Growth Rate (%)')
    ax3.tick_params(axis='x', rotation=45)
    ax3.grid(True, alpha=0.3, axis='y')
    
    # 4. Average Order Value
    ax4 = axes[1, 1]
    ax4.plot(revenue_df['order_month'], revenue_df['avg_order_value'], 
             marker='s', linewidth=2, markersize=6, color='#F18F01')
    ax4.set_title('Average Order Value Trend', fontsize=12, fontweight='bold')
    ax4.set_xlabel('Month')
    ax4.set_ylabel('AOV ($)')
    ax4.tick_params(axis='x', rotation=45)
    ax4.grid(True, alpha=0.3)
    
    plt.tight_layout()
    return fig


# =====================================================
# 2. CUSTOMER SEGMENTATION VISUALIZATION
# =====================================================

def plot_customer_segments(customer_df):
    """
    Visualize customer segmentation based on purchase behavior.
    """
    fig, axes = plt.subplots(2, 2, figsize=(16, 10))
    fig.suptitle('Customer Segmentation Analysis', fontsize=16, fontweight='bold')
    
    # 1. LTV Distribution
    ax1 = axes[0, 0]
    ax1.hist(customer_df['lifetime_value'], bins=50, color='#2E86AB', 
             alpha=0.7, edgecolor='black')
    ax1.axvline(customer_df['lifetime_value'].median(), color='red', 
                linestyle='--', linewidth=2, label=f'Median: ${customer_df["lifetime_value"].median():.2f}')
    ax1.axvline(customer_df['lifetime_value'].mean(), color='orange', 
                linestyle='--', linewidth=2, label=f'Mean: ${customer_df["lifetime_value"].mean():.2f}')
    ax1.set_title('Customer Lifetime Value Distribution', fontsize=12, fontweight='bold')
    ax1.set_xlabel('Lifetime Value ($)')
    ax1.set_ylabel('Number of Customers')
    ax1.legend()
    ax1.set_xlim(0, customer_df['lifetime_value'].quantile(0.95))
    
    # 2. Purchase Frequency
    ax2 = axes[0, 1]
    freq_counts = customer_df['total_orders'].value_counts().sort_index().head(10)
    ax2.bar(freq_counts.index, freq_counts.values, color='#A23B72', alpha=0.7)
    ax2.set_title('Purchase Frequency Distribution', fontsize=12, fontweight='bold')
    ax2.set_xlabel('Number of Orders')
    ax2.set_ylabel('Number of Customers')
    ax2.grid(True, alpha=0.3, axis='y')
    
    # 3. LTV vs Order Frequency
    ax3 = axes[1, 0]
    scatter = ax3.scatter(customer_df['total_orders'], 
                         customer_df['lifetime_value'],
                         alpha=0.5, s=50, c=customer_df['customer_age_days'],
                         cmap='viridis')
    ax3.set_title('Lifetime Value vs Purchase Frequency', fontsize=12, fontweight='bold')
    ax3.set_xlabel('Total Orders')
    ax3.set_ylabel('Lifetime Value ($)')
    ax3.set_ylim(0, customer_df['lifetime_value'].quantile(0.95))
    ax3.set_xlim(0, customer_df['total_orders'].quantile(0.95))
    plt.colorbar(scatter, ax=ax3, label='Customer Age (days)')
    
    # 4. Top States by Revenue
    ax4 = axes[1, 1]
    state_revenue = customer_df.groupby('customer_state')['lifetime_value'].sum().sort_values(ascending=False).head(10)
    ax4.barh(state_revenue.index, state_revenue.values, color='#F18F01', alpha=0.7)
    ax4.set_title('Top 10 States by Total Revenue', fontsize=12, fontweight='bold')
    ax4.set_xlabel('Total Revenue ($)')
    ax4.set_ylabel('State')
    ax4.grid(True, alpha=0.3, axis='x')
    
    plt.tight_layout()
    return fig


# =====================================================
# 3. COHORT RETENTION HEATMAP
# =====================================================

def plot_cohort_retention(cohort_df):
    """
    Create cohort retention heatmap.
    
    Visual representation of customer retention over time.
    """
    # Pivot data for heatmap
    cohort_pivot = cohort_df.pivot_table(
        index='cohort_month',
        columns='months_since_first',
        values='retention_pct',
        aggfunc='mean'
    )
    
    # Limit to first 12 months for readability
    cohort_pivot = cohort_pivot.iloc[:, :13]
    
    fig, ax = plt.subplots(figsize=(16, 10))
    
    # Create heatmap
    sns.heatmap(cohort_pivot, 
                annot=True, 
                fmt='.1f',
                cmap='RdYlGn',
                center=20,
                vmin=0,
                vmax=50,
                linewidths=0.5,
                cbar_kws={'label': 'Retention Rate (%)'},
                ax=ax)
    
    ax.set_title('Customer Cohort Retention Heatmap', 
                 fontsize=16, fontweight='bold', pad=20)
    ax.set_xlabel('Months Since First Purchase', fontsize=12)
    ax.set_ylabel('Cohort Month', fontsize=12)
    
    # Format y-axis dates
    y_labels = [d.strftime('%Y-%m') for d in cohort_pivot.index]
    ax.set_yticklabels(y_labels, rotation=0)
    
    plt.tight_layout()
    return fig


# =====================================================
# 4. PRODUCT PERFORMANCE VISUALIZATION
# =====================================================

def plot_product_performance(product_df):
    """
    Visualize product category performance.
    """
    fig, axes = plt.subplots(2, 1, figsize=(14, 10))
    fig.suptitle('Product Category Performance', fontsize=16, fontweight='bold')
    
    # Sort by revenue
    product_df = product_df.sort_values('total_revenue', ascending=False).head(15)
    
    # 1. Revenue by Category
    ax1 = axes[0]
    bars1 = ax1.barh(product_df['product_category'], 
                     product_df['total_revenue'],
                     color='#2E86AB', alpha=0.7)
    ax1.set_title('Total Revenue by Category', fontsize=12, fontweight='bold')
    ax1.set_xlabel('Total Revenue ($)')
    ax1.grid(True, alpha=0.3, axis='x')
    
    # Add value labels
    for i, (bar, value) in enumerate(zip(bars1, product_df['total_revenue'])):
        ax1.text(value, i, f' ${value:,.0f}', 
                va='center', fontsize=9)
    
    # 2. Orders vs AOV (Bubble chart)
    ax2 = axes[1]
    scatter = ax2.scatter(product_df['total_orders'], 
                         product_df['avg_order_value'],
                         s=product_df['total_revenue']/100,  # Size by revenue
                         alpha=0.6,
                         c=range(len(product_df)),
                         cmap='viridis')
    
    ax2.set_title('Order Volume vs Average Order Value (bubble size = revenue)', 
                  fontsize=12, fontweight='bold')
    ax2.set_xlabel('Total Orders')
    ax2.set_ylabel('Average Order Value ($)')
    ax2.grid(True, alpha=0.3)
    
    # Annotate top categories
    for idx, row in product_df.head(5).iterrows():
        ax2.annotate(row['product_category'][:20], 
                    (row['total_orders'], row['avg_order_value']),
                    fontsize=8, alpha=0.7)
    
    plt.tight_layout()
    return fig


# =====================================================
# 5. EXECUTIVE SUMMARY DASHBOARD
# =====================================================

def create_executive_summary(revenue_df, customer_df):
    """
    Create one-page executive summary with key metrics.
    """
    fig = plt.figure(figsize=(16, 10))
    gs = fig.add_gridspec(3, 3, hspace=0.3, wspace=0.3)
    
    fig.suptitle('Executive Summary Dashboard', fontsize=18, fontweight='bold')
    
    # Calculate key metrics
    total_revenue = revenue_df['revenue'].sum()
    total_orders = revenue_df['orders'].sum()
    avg_monthly_revenue = revenue_df['revenue'].mean()
    revenue_growth = revenue_df['revenue_growth'].mean()
    
    total_customers = len(customer_df)
    avg_ltv = customer_df['lifetime_value'].mean()
    repeat_rate = (customer_df['total_orders'] > 1).sum() / len(customer_df) * 100
    
    # 1. Key Metrics Cards (Top Row)
    metrics = [
        ('Total Revenue', f'${total_revenue:,.0f}', 'green'),
        ('Total Customers', f'{total_customers:,}', 'blue'),
        ('Avg LTV', f'${avg_ltv:.2f}', 'purple')
    ]
    
    for i, (label, value, color) in enumerate(metrics):
        ax = fig.add_subplot(gs[0, i])
        ax.text(0.5, 0.6, value, ha='center', va='center', 
               fontsize=32, fontweight='bold', color=color)
        ax.text(0.5, 0.3, label, ha='center', va='center', 
               fontsize=14, color='gray')
        ax.axis('off')
    
    # 2. Revenue Trend (Middle Left)
    ax_revenue = fig.add_subplot(gs[1, :2])
    ax_revenue.plot(revenue_df['order_month'], revenue_df['revenue'], 
                   marker='o', linewidth=3, markersize=8, color='#2E86AB')
    ax_revenue.fill_between(revenue_df['order_month'], revenue_df['revenue'], 
                           alpha=0.3, color='#2E86AB')
    ax_revenue.set_title('Monthly Revenue Trend', fontsize=12, fontweight='bold')
    ax_revenue.set_xlabel('Month')
    ax_revenue.set_ylabel('Revenue ($)')
    ax_revenue.tick_params(axis='x', rotation=45)
    ax_revenue.grid(True, alpha=0.3)
    
    # 3. Customer LTV Distribution (Middle Right)
    ax_ltv = fig.add_subplot(gs[1, 2])
    ax_ltv.hist(customer_df['lifetime_value'], bins=30, color='#A23B72', 
               alpha=0.7, edgecolor='black')
    ax_ltv.axvline(avg_ltv, color='red', linestyle='--', linewidth=2)
    ax_ltv.set_title('LTV Distribution', fontsize=12, fontweight='bold')
    ax_ltv.set_xlabel('LTV ($)')
    ax_ltv.set_ylabel('Customers')
    ax_ltv.set_xlim(0, customer_df['lifetime_value'].quantile(0.95))
    
    # 4. Top States (Bottom Left)
    ax_states = fig.add_subplot(gs[2, :2])
    state_revenue = customer_df.groupby('customer_state')['lifetime_value'].sum().sort_values(ascending=False).head(8)
    ax_states.barh(state_revenue.index, state_revenue.values, color='#F18F01', alpha=0.7)
    ax_states.set_title('Top 8 States by Revenue', fontsize=12, fontweight='bold')
    ax_states.set_xlabel('Revenue ($)')
    ax_states.grid(True, alpha=0.3, axis='x')
    
    # 5. Key Insights Box (Bottom Right)
    ax_insights = fig.add_subplot(gs[2, 2])
    insights_text = f"""
    KEY INSIGHTS
    
    📈 Avg Monthly Growth: {revenue_growth:.1f}%
    
    👥 Repeat Rate: {repeat_rate:.1f}%
    
    💰 Avg Order Value: ${revenue_df['avg_order_value'].mean():.2f}
    
    📦 Total Orders: {total_orders:,}
    
    🏆 Top State: {customer_df.groupby('customer_state')['lifetime_value'].sum().idxmax()}
    """
    ax_insights.text(0.1, 0.9, insights_text, 
                    fontsize=11, verticalalignment='top',
                    family='monospace', bbox=dict(boxstyle='round', 
                    facecolor='wheat', alpha=0.3))
    ax_insights.axis('off')
    
    return fig


# =====================================================
# SAVE FUNCTIONS
# =====================================================

def save_all_visualizations(revenue_df, customer_df, cohort_df, product_df, 
                           output_dir='visualizations'):
    """
    Generate and save all visualizations.
    """
    import os
    os.makedirs(output_dir, exist_ok=True)
    
    print("Generating visualizations...")
    
    # 1. Revenue Trends
    print("  1/5 Revenue trends...")
    fig1 = plot_revenue_trends(revenue_df)
    fig1.savefig(f'{output_dir}/01_revenue_trends.png', dpi=300, bbox_inches='tight')
    plt.close(fig1)
    
    # 2. Customer Segments
    print("  2/5 Customer segments...")
    fig2 = plot_customer_segments(customer_df)
    fig2.savefig(f'{output_dir}/02_customer_segments.png', dpi=300, bbox_inches='tight')
    plt.close(fig2)
    
    # 3. Cohort Retention
    print("  3/5 Cohort retention...")
    fig3 = plot_cohort_retention(cohort_df)
    fig3.savefig(f'{output_dir}/03_cohort_retention.png', dpi=300, bbox_inches='tight')
    plt.close(fig3)
    
    # 4. Product Performance
    print("  4/5 Product performance...")
    fig4 = plot_product_performance(product_df)
    fig4.savefig(f'{output_dir}/04_product_performance.png', dpi=300, bbox_inches='tight')
    plt.close(fig4)
    
    # 5. Executive Summary
    print("  5/5 Executive summary...")
    fig5 = create_executive_summary(revenue_df, customer_df)
    fig5.savefig(f'{output_dir}/05_executive_summary.png', dpi=300, bbox_inches='tight')
    plt.close(fig5)
    
    print(f"\n✓ All visualizations saved to '{output_dir}/' directory")


# =====================================================
# MAIN EXECUTION
# =====================================================

if __name__ == "__main__":
    print("="*60)
    print("VISUALIZATION GENERATION")
    print("="*60)
    print("\nNote: This script requires data from database.")
    print("Make sure to run 06_Python_SQL_Connection.py first")
    print("\nTo use: Load your dataframes and call:")
    print("  save_all_visualizations(revenue_df, customer_df, cohort_df, product_df)")


"""
VISUALIZATION BEST PRACTICES:

1. CLARITY
   ✓ Clear titles and labels
   ✓ Appropriate chart types for data
   ✓ Consistent color schemes
   ✓ Remove chart junk

2. BUSINESS FOCUS
   ✓ Answer specific questions
   ✓ Highlight key insights
   ✓ Use business-friendly language
   ✓ Include context (benchmarks, targets)

3. TECHNICAL QUALITY
   ✓ High resolution (300 DPI)
   ✓ Proper scaling and limits
   ✓ Professional styling
   ✓ Accessible colors

4. STORYTELLING
   ✓ Logical flow
   ✓ Progressive disclosure
   ✓ Visual hierarchy
   ✓ Actionable insights

COMMON MISTAKES TO AVOID:
✗ 3D charts (hard to read)
✗ Too many colors
✗ Pie charts with >5 slices
✗ Misleading axes
✗ Missing labels/legends
✗ Low resolution exports
"""