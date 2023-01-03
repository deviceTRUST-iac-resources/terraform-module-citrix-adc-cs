#####
# Add Content Switching Actions
#####

resource "citrixadc_csaction" "cs_action_lb" {
  count         = length(var.adc-cs-action-lb.name)
  name          = element(var.adc-cs-action-lb["name"],count.index)
  targetlbvserver = element(var.adc-cs-action-lb["targetlbvserver"],count.index)
}

resource "citrixadc_csaction" "cs_action_gw" {
  count         = length(var.adc-cs-action-gw.name)
  name          = element(var.adc-cs-action-gw["name"],count.index)
  targetvserver = element(var.adc-cs-action-gw["targetvserver"],count.index)
}

#####
# Add Content Switching Policies
#####

resource "citrixadc_cspolicy" "cs_policy" {
  count      = length(var.adc-cs-policy.policyname)
  policyname = element(var.adc-cs-policy["policyname"],count.index)
  rule       = element(var.adc-cs-policy["rule"],count.index)
  action     = element(var.adc-cs-policy["action"],count.index)

  depends_on = [
    citrixadc_csaction.cs_action_lb,
    citrixadc_csaction.cs_action_gw
  ]

}

#####
# Add Content Switching vServer
#####
resource "citrixadc_csvserver" "cs_vserver" {
  count       = length(var.adc-cs-vserver.name)
  name        = element(var.adc-cs-vserver["name"],count.index)
  ipv46       = element(var.adc-cs-vserver["ipv46"],count.index)
  port        = element(var.adc-cs-vserver["port"],count.index)
  servicetype = element(var.adc-cs-vserver["servicetype"],count.index)
  sslprofile  = element(var.adc-cs-vserver["sslprofile"],count.index)
  httpprofilename = element(var.adc-cs-vserver["httpprofile"],count.index)
  tcpprofilename  = element(var.adc-cs-vserver["tcpprofile"],count.index)

  depends_on = [
    citrixadc_cspolicy.cs_policy
  ]
}

#####
# Bind Content Switching Policies to Content Switching vServer
#####

resource "citrixadc_csvserver_cspolicy_binding" "cs_vserverpolicybinding" {
    count          = length(var.adc-cs-vserver-cspolicybinding.policyname)
    name           = element(var.adc-cs-vserver-cspolicybinding["name"],count.index)
    policyname     = element(var.adc-cs-vserver-cspolicybinding["policyname"],count.index)
    priority       = element(var.adc-cs-vserver-cspolicybinding["priority"],count.index)
    # gotopriorityexpression = element(var.adc-cs-vserver-cspolicybinding["gotopriorityexpression"],count.index)

  depends_on  = [
    citrixadc_csvserver.cs_vserver
  ]
}

#####
# Bind SSL certificate to CS vServers
#####

resource "citrixadc_sslvserver_sslcertkey_binding" "cs_sslvserver_sslcertkey_binding" {
    count       = length(var.adc-cs-vserver.name)
    vservername = element(var.adc-cs-vserver["name"],count.index)
    certkeyname = "ssl_cert_democloud"
    snicert     = false

    depends_on  = [
      citrixadc_csvserver.cs_vserver
    ]
}

#####
# Save config
#####

resource "citrixadc_nsconfig_save" "cs_save" {
    
    all        = true
    timestamp  = timestamp()

    depends_on = [
        citrixadc_csvserver_cspolicy_binding.cs_vserverpolicybinding,
        citrixadc_sslvserver_sslcertkey_binding.cs_sslvserver_sslcertkey_binding
    ]

}

#####
# Wait for config save to commence properly, before allowing the subsequent module to run.
#####


resource "time_sleep" "cs_wait" {

  create_duration = "5s"

  depends_on = [
    citrixadc_nsconfig_save.cs_save
  ]

}