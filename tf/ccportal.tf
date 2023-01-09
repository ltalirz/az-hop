resource "azurerm_network_interface" "ccportal-nic" {
  name                = "ccportal-nic"
  location            = local.create_rg ? azurerm_resource_group.rg[0].location : data.azurerm_resource_group.rg[0].location
  resource_group_name = local.create_rg ? azurerm_resource_group.rg[0].name : data.azurerm_resource_group.rg[0].name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = local.create_admin_subnet ? azurerm_subnet.admin[0].id : data.azurerm_subnet.admin[0].id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "ccportal" {
  name                = "ccportal"
  location            = local.create_rg ? azurerm_resource_group.rg[0].location : data.azurerm_resource_group.rg[0].location
  resource_group_name = local.create_rg ? azurerm_resource_group.rg[0].name : data.azurerm_resource_group.rg[0].name
  size                = try(local.configuration_yml["cyclecloud"].vm_size, "Standard_B2ms")
  admin_username      = local.admin_username
  network_interface_ids = [
    azurerm_network_interface.ccportal-nic.id,
  ]

  admin_ssh_key {
    username   = local.admin_username
    public_key = tls_private_key.internal.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [ azurerm_user_assigned_identity.ccportal.id ]
  }

  dynamic "source_image_reference" {
    for_each = local.use_linux_image_id ? [] : [1]
    content {
      publisher = local.linux_base_image_reference.publisher
      offer     = local.linux_base_image_reference.offer
      sku       = local.linux_base_image_reference.sku
      version   = local.linux_base_image_reference.version
    }
  }

  source_image_id = local.linux_image_id
  dynamic "plan" {
    for_each = try (length(local.linux_image_plan.name) > 0, false) ? [1] : []
    content {
        name      = local.linux_image_plan.name
        publisher = local.linux_image_plan.publisher
        product   = local.linux_image_plan.product
    }
  }
  
  lifecycle {
    ignore_changes = [
      tags
    ]
  }
}

resource "azurerm_managed_disk" "ccportal_datadisk" {
  name                 = "ccportal-datadisk0"
  location             = local.create_rg ? azurerm_resource_group.rg[0].location : data.azurerm_resource_group.rg[0].location
  resource_group_name  = local.create_rg ? azurerm_resource_group.rg[0].name : data.azurerm_resource_group.rg[0].name
  storage_account_type = "Premium_LRS"
  create_option        = "Empty"
  disk_size_gb         = 128
}

resource "azurerm_virtual_machine_data_disk_attachment" "ccportal" {
  managed_disk_id    = azurerm_managed_disk.ccportal_datadisk.id
  virtual_machine_id = azurerm_linux_virtual_machine.ccportal.id
  lun                = "0"
  caching            = "ReadWrite"
}

data "azurerm_role_definition" "contributor" {
  name = "Contributor"
}

data "azurerm_role_definition" "reader" {
  name = "Reader"
}

resource "azurerm_user_assigned_identity" "ccportal" {
  location            = local.create_rg ? azurerm_resource_group.rg[0].location : data.azurerm_resource_group.rg[0].location
  resource_group_name = local.create_rg ? azurerm_resource_group.rg[0].name : data.azurerm_resource_group.rg[0].name
  name = "ccportal"
}

# resource "random_uuid" "role" {
# }


# resource "azurerm_role_definition" "cyclecloud" {
#   role_definition_id = random_uuid.role.result
#   name               = "CycleCloud-${random_string.resource_postfix.result}"
#   description        = "CycleCloud Orchestrator Role"
#   scope              = data.azurerm_subscription.primary.id

#   permissions {
#     actions     = [ "Microsoft.Commerce/RateCard/read",
#                     "Microsoft.Compute/*/read",
#                     "Microsoft.Compute/availabilitySets/*",
#                     "Microsoft.Compute/disks/*",
#                     "Microsoft.Compute/images/read",
#                     "Microsoft.Compute/locations/usages/read",
#                     "Microsoft.Compute/register/action",
#                     "Microsoft.Compute/skus/read",
#                     "Microsoft.Compute/virtualMachines/*",
#                     "Microsoft.Compute/virtualMachineScaleSets/*",
#                     "Microsoft.Compute/virtualMachineScaleSets/virtualMachines/*",
#                     "Microsoft.ManagedIdentity/userAssignedIdentities/*/assign/action",
#                     "Microsoft.Network/*/read",
#                     "Microsoft.Network/locations/*/read",
#                     "Microsoft.Network/networkInterfaces/read",
#                     "Microsoft.Network/networkInterfaces/write",
#                     "Microsoft.Network/networkInterfaces/delete",
#                     "Microsoft.Network/networkInterfaces/join/action",
#                     "Microsoft.Network/networkSecurityGroups/read",
#                     "Microsoft.Network/networkSecurityGroups/write",
#                     "Microsoft.Network/networkSecurityGroups/delete",
#                     "Microsoft.Network/networkSecurityGroups/join/action",
#                     "Microsoft.Network/publicIPAddresses/read",
#                     "Microsoft.Network/publicIPAddresses/write",
#                     "Microsoft.Network/publicIPAddresses/delete",
#                     "Microsoft.Network/publicIPAddresses/join/action",
#                     "Microsoft.Network/register/action",
#                     "Microsoft.Network/virtualNetworks/read",
#                     "Microsoft.Network/virtualNetworks/subnets/read",
#                     "Microsoft.Network/virtualNetworks/subnets/join/action",
#                     "Microsoft.Resources/deployments/read",
#                     "Microsoft.Resources/subscriptions/resourceGroups/read",
#                     "Microsoft.Resources/subscriptions/resourceGroups/resources/read",
#                     "Microsoft.Resources/subscriptions/operationresults/read",
#                     "Microsoft.Storage/*/read",
#                     "Microsoft.Storage/checknameavailability/read",
#                     "Microsoft.Storage/register/action",
#                     "Microsoft.Storage/storageAccounts/read",
#                     "Microsoft.Storage/storageAccounts/listKeys/action",
#                     "Microsoft.Storage/storageAccounts/write"]
#     not_actions = []
#   }
# }

# Grant Contributor access to Cycle in the az-hop resource group
resource "azurerm_role_assignment" "ccportal_rg" {
#  name               = azurerm_user_assigned_identity.ccportal.principal_id
  scope              = local.create_rg ? azurerm_resource_group.rg[0].id : data.azurerm_resource_group.rg[0].id
  role_definition_id = "${data.azurerm_subscription.primary.id}${data.azurerm_role_definition.contributor.id}"
  principal_id       = azurerm_user_assigned_identity.ccportal.principal_id
}

# Grant Subscription Reader access to Cycle
resource "azurerm_role_assignment" "ccportal_sub_reader" {
  scope              = "${data.azurerm_subscription.primary.id}"
  role_definition_id = "${data.azurerm_subscription.primary.id}${data.azurerm_role_definition.reader.id}"
  principal_id       = azurerm_user_assigned_identity.ccportal.principal_id
}

resource "azurerm_network_interface_application_security_group_association" "ccportal-asg-asso" {
  for_each = toset(local.asg_associations["ccportal"])
  network_interface_id          = azurerm_network_interface.ccportal-nic.id
  application_security_group_id = local.create_nsg ? azurerm_application_security_group.asg[each.key].id : data.azurerm_application_security_group.asg[each.key].id
}

resource "azurerm_virtual_machine_extension" "AzureMonitorLinuxAgent_ccportal" {
  depends_on = [
    azurerm_linux_virtual_machine.ccportal
  ]
  name                       = "AzureMonitorLinuxAgent"
  virtual_machine_id         = azurerm_linux_virtual_machine.ccportal.id
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorLinuxAgent"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true

  settings                   = <<SETTINGS
  {
    "authentication": {
      "managedIdentity": {
        "identifier-name": "mi_res_id",
        "identifier-value": "${azurerm_user_assigned_identity.ccportal.id}" 
      }
    }
  }
  SETTINGS
}

resource "azurerm_monitor_data_collection_rule_association" "dcra_ccportal_metrics" {
    name                = "ccportal-data-collection-ra"
    target_resource_id = azurerm_linux_virtual_machine.ccportal.id
    data_collection_rule_id = azurerm_monitor_data_collection_rule.vm_data_collection_rule.id
    description = "CCPortal Data Collection Rule Association for VM Metrics"
}

resource "azurerm_monitor_data_collection_rule_association" "dcra_ccportal_insights" {
    name                = "ccportal-insights-collection-ra"
    target_resource_id = azurerm_linux_virtual_machine.ccportal.id
    data_collection_rule_id = azurerm_monitor_data_collection_rule.vm_insights_collection_rule.id
    description = "CCPortal Data Collection Rule Association for VM Insights"
}

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "ccportal_volume_alert" {
    name = "ccportal-volume-alert"
    location = local.create_rg ? azurerm_resource_group.rg[0].location : data.azurerm_resource_group.rg[0].location
    resource_group_name = local.create_rg ? azurerm_resource_group.rg[0].name : data.azurerm_resource_group.rg[0].name


    evaluation_frequency = "PT5M"
    window_duration = "PT5M"
    scopes = [azurerm_linux_virtual_machine.ccportal.id]
    severity = 3

    criteria {
        query = <<-QUERY
          InsightsMetrics
          | where TimeGenerated >= ago(5min) and Name == "FreeSpacePercentage" and Val <= 20
          | project TimeGenerated, Computer, Name, Val, Tags, _ResourceId
          | summarize arg_max(TimeGenerated, *) by Tags
          | project Tags, Val, Computer, _ResourceId
          QUERY
        time_aggregation_method = "Count"
        operator = "GreaterThan"
        threshold = 0
        failing_periods {
            minimum_failing_periods_to_trigger_alert = 1
            number_of_evaluation_periods = 1
        }
    }

    auto_mitigation_enabled = true
    description = "Alert when the volumes of the ccportal VM is above 80%"
    display_name = "ccportal volumes full"
    enabled = true
    query_time_range_override = "P2D"

    action {
        action_groups = [azurerm_monitor_action_group.azhop_action_group.id]
    }
}

resource "azurerm_monitor_metric_alert" "ccportal_disk_alert" {
  name                = "ccportal-disk-alert"
  resource_group_name = local.create_rg ? azurerm_resource_group.rg[0].name : data.azurerm_resource_group.rg[0].name
  scopes              = [azurerm_linux_virtual_machine.ccportal.id]
  description         = "Alert when cyclecloud VM disk is 80% full"
  severity            = 3
  enabled             = true
  frequency           = "PT5M"
  window_size         = "PT5M"
  target_resource_type = "Microsoft.Compute/virtualMachines"
  target_resource_location = local.create_rg ? azurerm_resource_group.rg[0].location : data.azurerm_resource_group.rg[0].location
  criteria {
    metric_namespace = "Azure.VM.Linux.GuestMetrics"
    metric_name      = "disk/free_percent"
    aggregation      = "Average"
    operator         = "LessThanOrEqual"
    threshold        = 20
  }
  action {
    action_group_id = azurerm_monitor_action_group.azhop_action_group.id
  }
}

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "ccportal_service_alert" {
    name = "ccportal-service-alert"
    location = local.create_rg ? azurerm_resource_group.rg[0].location : data.azurerm_resource_group.rg[0].location
    resource_group_name = local.create_rg ? azurerm_resource_group.rg[0].name : data.azurerm_resource_group.rg[0].name


    evaluation_frequency = "PT5M"
    window_duration = "PT5M"
    scopes = [azurerm_linux_virtual_machine.ccportal.id]
    severity = 3

    criteria {
        query = <<-QUERY
          Syslog
          | where TimeGenerated >= ago(5min) and Facility == "daemon" and (SyslogMessage == "Stopped CycleCloud." or SyslogMessage == "webserver is already stopped.")
          QUERY
        time_aggregation_method = "Count"
        operator = "GreaterThan"
        threshold = 0
        failing_periods {
            minimum_failing_periods_to_trigger_alert = 1
            number_of_evaluation_periods = 1
        }
    }

    auto_mitigation_enabled = false
    description = "Alert when the cycle_server service is stopped on the ccportal VM"
    display_name = "CycleCloud stopped on ccportal"
    enabled = true
    query_time_range_override = "P2D"

    action {
        action_groups = [azurerm_monitor_action_group.azhop_action_group.id]
    }
}
