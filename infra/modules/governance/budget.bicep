targetScope = 'subscription'

@description('Name of the subscription budget resource.')
param budgetName string

@description('Monthly budget amount in the subscription billing currency.')
@minValue(1)
param amount int

@description('Budget period start date in ISO 8601 format.')
param startDate string

@description('Email recipients for budget notifications.')
param contactEmails array

resource subscriptionBudget 'Microsoft.Consumption/budgets@2024-08-01' = {
  name: budgetName
  properties: {
    amount: amount
    category: 'Cost'
    timeGrain: 'Monthly'
    timePeriod: {
      startDate: startDate
    }
    notifications: {
      advisoryActual: {
        enabled: true
        operator: 'GreaterThanOrEqualTo'
        threshold: 50
        thresholdType: 'Actual'
        contactEmails: contactEmails
        contactGroups: []
        contactRoles: []
        locale: 'en-us'
      }
      warningActual: {
        enabled: true
        operator: 'GreaterThanOrEqualTo'
        threshold: 80
        thresholdType: 'Actual'
        contactEmails: contactEmails
        contactGroups: []
        contactRoles: []
        locale: 'en-us'
      }
      forecastCritical: {
        enabled: true
        operator: 'GreaterThanOrEqualTo'
        threshold: 100
        thresholdType: 'Forecasted'
        contactEmails: contactEmails
        contactGroups: []
        contactRoles: []
        locale: 'en-us'
      }
    }
  }
}

output summary object = {
  name: subscriptionBudget.name
  amount: amount
  timeGrain: 'Monthly'
  notifications: {
    actual50: 50
    actual80: 80
    forecast100: 100
  }
}
