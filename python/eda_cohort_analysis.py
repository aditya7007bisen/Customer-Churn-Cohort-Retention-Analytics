import os
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt

data_dir = r'c:\Users\Akanksha\Downloads\Customer-Churn-Cohort-Retention-Analytics\data'
dash_dir = r'c:\Users\Akanksha\Downloads\Customer-Churn-Cohort-Retention-Analytics\dashboard'

df_cust = pd.read_csv(os.path.join(data_dir, 'customers.csv'))
df_tx = pd.read_csv(os.path.join(data_dir, 'transactions.csv'))

df_tx['transaction_date'] = pd.to_datetime(df_tx['transaction_date'])
df_tx['transaction_month'] = pd.to_datetime(df_tx['transaction_month'])
df_tx['cohort_month'] = pd.to_datetime(df_tx['cohort_month'])

# Cohort Index calculation
df_tx['cohort_index'] = (df_tx['transaction_month'].dt.year - df_tx['cohort_month'].dt.year) * 12 + \
                        (df_tx['transaction_month'].dt.month - df_tx['cohort_month'].dt.month)

cohort_counts = df_tx.groupby(['cohort_month', 'cohort_index'])['customer_id'].nunique().reset_index()
cohort_pivot = cohort_counts.pivot(index='cohort_month', columns='cohort_index', values='customer_id')

cohort_sizes = cohort_pivot.iloc[:, 0]
retention_matrix = cohort_pivot.divide(cohort_sizes, axis=0) * 100

print('Retention Matrix shape:', retention_matrix.shape)

# 1. PLOT COHORT RETENTION HEATMAP
plt.figure(figsize=(12, 7))
plt.imshow(retention_matrix, cmap='YlGnBu', aspect='auto', vmin=20, vmax=100)
plt.colorbar(label='Retention Rate (%)')
plt.title('SaaS Customer Cohort Retention Matrix (2024)', fontsize=14, fontweight='bold', pad=15)
plt.xlabel('Cohort Index (Months Active)', fontsize=11, fontweight='bold')
plt.ylabel('Cohort Signup Month', fontsize=11, fontweight='bold')

plt.xticks(range(len(retention_matrix.columns)), [f'Month {col}' for col in retention_matrix.columns], rotation=45)
plt.yticks(range(len(retention_matrix.index)), [idx.strftime('%Y-%m') for idx in retention_matrix.index])

for i in range(len(retention_matrix.index)):
    for j in range(len(retention_matrix.columns)):
        val = retention_matrix.iloc[i, j]
        if not np.isnan(val):
            plt.text(j, i, f'{val:.1f}%', ha='center', va='center', color='black' if val < 70 else 'white', fontsize=9, fontweight='bold')

plt.tight_layout()
heatmap_path = os.path.join(dash_dir, 'cohort_retention_heatmap.png')
plt.savefig(heatmap_path, dpi=200)
plt.close()
print(f'Heatmap saved -> {heatmap_path}')

# 2. PLOT EXECUTIVE CHURN DASHBOARD OVERVIEW
fig, axs = plt.subplots(2, 2, figsize=(14, 10))
fig.suptitle('Customer Churn Risk & Retention Analytics Dashboard', fontsize=16, fontweight='bold', y=0.98)

# Panel 1: Churn Rate by Plan Tier
plan_churn = df_cust.groupby('plan_tier')['is_churned'].mean() * 100
axs[0, 0].bar(plan_churn.index, plan_churn.values, color=['#3498db', '#2ecc71', '#e74c3c'], width=0.45)
axs[0, 0].set_title('Churn Rate by Plan Tier (%)', fontweight='bold')
axs[0, 0].set_ylabel('Churn Rate (%)')
for i, v in enumerate(plan_churn.values):
    axs[0, 0].text(i, v + 0.8, f'{v:.1f}%', ha='center', fontweight='bold')

# Panel 2: Churn by Acquisition Channel
chan_churn = df_cust.groupby('acquisition_channel')['is_churned'].mean().sort_values() * 100
axs[0, 1].barh(chan_churn.index, chan_churn.values, color='#9b59b6', height=0.45)
axs[0, 1].set_title('Churn Rate by Acquisition Channel (%)', fontweight='bold')
axs[0, 1].set_xlabel('Churn Rate (%)')
for i, v in enumerate(chan_churn.values):
    axs[0, 1].text(v + 0.5, i, f'{v:.1f}%', va='center', fontweight='bold')

# Panel 3: Churn vs Support Tickets
df_cust['ticket_tier'] = pd.cut(df_cust['support_tickets'], bins=[-1, 0, 2, 4, 15], labels=['0 Tickets', '1-2 Tickets', '3-4 Tickets', '5+ Tickets'])
tick_churn = df_cust.groupby('ticket_tier', observed=False)['is_churned'].mean() * 100
axs[1, 0].plot(tick_churn.index, tick_churn.values, marker='o', linewidth=3, color='#e67e22', markersize=8)
axs[1, 0].set_title('Support Ticket Volume vs Churn Spikes', fontweight='bold')
axs[1, 0].set_ylabel('Churn Rate (%)')
axs[1, 0].grid(True, linestyle='--', alpha=0.5)
for i, v in enumerate(tick_churn.values):
    axs[1, 0].text(i, v + 2, f'{v:.1f}%', ha='center', fontweight='bold')

# Panel 4: Churn Reasons Breakdown
reasons = df_cust[df_cust['is_churned'] == 1]['churn_reason'].value_counts()
axs[1, 1].pie(reasons.values, labels=reasons.index, autopct='%1.1f%%', colors=['#e74c3c', '#f39c12', '#34495e', '#16a085', '#7f8c8d'], startangle=140)
axs[1, 1].set_title('Primary Churn Reasons Distribution', fontweight='bold')

plt.tight_layout()
dash_path = os.path.join(dash_dir, 'churn_executive_summary.png')
plt.savefig(dash_path, dpi=200)
plt.close()
print(f'Dashboard summary saved -> {dash_path}')
