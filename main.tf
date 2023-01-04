locals {
  cs_vserver_port        = 443
  cs_vserver_type        = "SSL"
  cs_vserver_sslprofile  = "ssl_prof_${var.adc-base.environmentname}_fe_TLS1213"
  cs_vserver_httpprofile = "http_prof_${var.adc-base.environmentname}"
  cs_vserver_tcpprofile  = "tcp_prof_${var.adc-base.environmentname}"
}

#####
# Add Content Switching Actions
#####

resource "citrixadc_csaction" "cs_action_lb" {
  count           = length(var.adc-lb.name)
  name            = "cs_act_${element(var.adc-lb["name"],count.index)}_${element(var.adc-lb["type"],count.index)}_${element(var.adc-lb["port"],count.index)}"
  targetlbvserver = "lb_vs_${element(var.adc-lb["name"],count.index)}_${element(var.adc-lb["type"],count.index)}_${element(var.adc-lb["port"],count.index)}"
}

resource "citrixadc_csaction" "cs_action_gw" {
  count           = length(var.adc-cs-gw.name)
  name            = "cs_act_${element(var.adc-cs-gw["name"],count.index)}_${element(var.adc-cs-gw["type"],count.index)}_${element(var.adc-cs-gw["port"],count.index)}"
  targetlbvserver = "gw_vs_${element(var.adc-cs-gw["name"],count.index)}_ssl_443"
}

#####
# Add Content Switching Policies
#####
resource "citrixadc_cspolicy" "cs_policy_lb" {
  count      = length(var.adc-lb.name)
  policyname = "cs_pol_${element(var.adc-lb["name"],count.index)}_${element(var.adc-lb["type"],count.index)}_${element(var.adc-lb["port"],count.index)}"
  rule       = "HTTP.REQ.HOSTNAME.CONTAINS(\"${element(var.adc-lb["name"],count.index)}\")"
  action     = "cs_act_${element(var.adc-lb["name"],count.index)}_${element(var.adc-lb["type"],count.index)}_${element(var.adc-lb["port"],count.index)}"

  depends_on = [
    citrixadc_csaction.cs_action_lb,
    citrixadc_csaction.cs_action_gw
  ]
}

resource "citrixadc_cspolicy" "cs_policy_gw" {
  count      = length(var.adc-cs-gw.name)
  policyname = "cs_pol_${element(var.adc-cs-gw["name"],count.index)}_ssl_443"
  rule       = "HTTP.REQ.HOSTNAME.CONTAINS(\"${element(var.adc-cs-gw["name"],count.index)}\")"
  action     = "cs_act_${element(var.adc-cs-gw["name"],count.index)}_ssl_443"

  depends_on = [
    citrixadc_csaction.cs_action_lb,
    citrixadc_csaction.cs_action_gw
  ]
}

#####
# Add Content Switching vServer
#####
resource "citrixadc_csvserver" "cs_vserver" {
  name            = var.adc-cs.vserver_name
  ipv46           = var.adc-cs.vserver_ip
  port            = local.cs_vserver_port
  servicetype     = local.cs_vserver_type
  sslprofile      = local.cs_vserver_sslprofile
  httpprofilename = local.cs_vserver_httpprofile
  tcpprofilename  = local.cs_vserver_tcpprofile

  depends_on = [
    citrixadc_cspolicy.cs_policy_lb,
    citrixadc_cspolicy.cs_policy_gw
  ]
}

#####
# Bind Content Switching Policies to Content Switching vServer
#####
resource "citrixadc_csvserver_cspolicy_binding" "cs_vserverpolicybinding_lb" {
    count                  = length(var.adc-lb.name)
    name                   = citrixadc_csvserver.cs_vserver.name
    policyname             = citrixadc_cspolicy.cs_policy_lb[count.index].policyname
    priority               = count.index * 10
    gotopriorityexpression = "END"
 
  depends_on  = [
    citrixadc_csvserver.cs_vserver
  ]
}

resource "citrixadc_csvserver_cspolicy_binding" "cs_vserverpolicybinding_gw" {
    count                  = length(var.adc-cs-gw.name)
    name                   = citrixadc_csvserver.cs_vserver.name
    policyname             = "cs_pol_${element(var.adc-cs-gw["name"],count.index)}"
    priority               = count.index * 1000
    gotopriorityexpression = "END"

  depends_on  = [
    citrixadc_csvserver.cs_vserver
  ]
}
#resource "citrixadc_csvserver_cspolicy_binding" "cs_vserverpolicybinding_lb" {
#    count                  = length(var.adc-lb.name)
#    name                   = citrixadc_csvserver.cs_vserver.name
#    policyname             = "cs_pol_${element(var.adc-lb["name"],count.index)}"
#    priority               = count.index * 10
#    gotopriorityexpression = "END"

#  depends_on  = [
#    citrixadc_csvserver.cs_vserver
#  ]
#}

#resource "citrixadc_csvserver_cspolicy_binding" "cs_vserverpolicybinding_gw" {
#    count                  = length(var.adc-cs-gw.name)
#    name                   = citrixadc_csvserver.cs_vserver.name
#    policyname             = "cs_pol_${element(var.adc-cs-gw["name"],count.index)}"
#    priority               = count.index * 1000
#    gotopriorityexpression = "END"

#  depends_on  = [
    #citrixadc_csvserver.cs_vserver
#  ]
#}

#####
# Bind SSL certificate to CS vServers
#####

#resource "citrixadc_sslvserver_sslcertkey_binding" "cs_sslvserver_sslcertkey_binding" {
#    vservername = citrixadc_csvserver.cs_vserver.name
#    certkeyname = "ssl_cert_${var.adc-base.environmentname}"
#    snicert     = false

#    depends_on  = [
#      citrixadc_csvserver.cs_vserver
#    ]
#}

#####
# Save config
#####
resource "citrixadc_nsconfig_save" "cs_save" {
    
    all        = true
    timestamp  = timestamp()

    depends_on = [
        citrixadc_csvserver_cspolicy_binding.cs_vserverpolicybinding_gw,
        citrixadc_csvserver_cspolicy_binding.cs_vserverpolicybinding_lb
    ]

}