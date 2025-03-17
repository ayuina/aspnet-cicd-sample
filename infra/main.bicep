param region string
param isproduction bool
param postfix string

//var postfix = toLower(uniqueString(subscription().id, resourceGroup().name, region))
var appSvcName = 'web-${postfix}'
var appSvcPlanName = 'asp-${appSvcName}'
var sqlSvrName = 'sqlsvr-${postfix}'
var sqlDbName = 'sqldb-${postfix}'
var sqlUserName = 'sqluser'
var sqlUserPassword = 'P@ss${uniqueString(resourceGroup().id)}'
var sqlConstrName = 'MvcMovieContext'
var sqlConstr = 'Server=tcp:${sqlsvr.properties.fullyQualifiedDomainName},1433; Database=${sqlDbName}; User ID=${sqlUserName}; Password=${sqlUserPassword};Trusted_Connection=False;Encrypt=True;'
var logAnalyticsName = 'laws-${postfix}'
var appInsightsName = 'ai-${appSvcName}'

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsName
  location: region
  properties:{
    sku:{
      name: 'PerGB2018'
    }
    retentionInDays: 30
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    workspaceCapping: {
      dailyQuotaGb: -1
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

resource appinsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: region
  kind: 'web'
  properties:{
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

resource asp 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: appSvcPlanName
  location: region
  sku: {
    name: 'S1'
    capacity: 1
  }
}

resource web 'Microsoft.Web/sites@2022-09-01' = {
  name: appSvcName
  location: region
  properties:{
    serverFarmId: asp.id
    clientAffinityEnabled: false
    siteConfig: {
      netFrameworkVersion: 'v8.0'
      ftpsState: 'Disabled'
      use32BitWorkerProcess: false
    }
  }
  tags: {
    amamonitor: 'target'
  }
}

resource metadata 'Microsoft.Web/sites/config@2022-09-01' = {
  name: 'metadata'
  parent: web
  properties: {
    CURRENT_STACK: 'dotnet'
  }
}

resource appsettings 'Microsoft.Web/sites/config@2022-03-01' = {
  name: 'appsettings'
  parent: web
  properties: {
    APPINSIGHTS_INSTRUMENTATIONKEY: appinsights.properties.InstrumentationKey
    APPLICATIONINSIGHTS_CONNECTION_STRING: appinsights.properties.ConnectionString
    ApplicationInsightsAgent_EXTENSION_VERSION: '~2'
    XDT_MicrosoftApplicationInsights_Mode: 'Recommended'
    ASPNETCORE_ENVIRONMENT: isproduction ? 'Production' : 'Development'
  }
}

resource sqlsvr 'Microsoft.Sql/servers@2021-11-01' = {
  name: sqlSvrName
  location: region
  properties: {
    administratorLogin: sqlUserName
    administratorLoginPassword: sqlUserPassword
  }
}

resource sqldb 'Microsoft.Sql/servers/databases@2021-11-01' = {
  name: sqlDbName
  parent: sqlsvr
  location: region
  sku: {
    name: 'GP_S_Gen5_1'
  }
}

resource sqlconstr 'Microsoft.Web/sites/config@2022-03-01' = {
  name: 'connectionstrings'
  parent: web
  properties: {
    '${sqlConstrName}' : {
      type: 'SQLAzure'
      value: sqlConstr
    }
  }
}

resource sqlfw 'Microsoft.Sql/servers/firewallRules@2021-11-01' = {
  parent: sqlsvr
  name: 'AllowAllWindowsAzureIps'
  properties: {
    startIpAddress:'0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

output webapiEndpoint string = 'https://${web.properties.enabledHostNames[0]}'
output kuduEndpoint string = 'https://${web.properties.enabledHostNames[1]}'
