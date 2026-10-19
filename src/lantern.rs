use base::config::keys;
use hbb_common::{
    config::{
        Config, APP_NAME, DEFAULT_SETTINGS, EXE_RENDEZVOUS_SERVER, HARD_SETTINGS,
        OVERWRITE_LOCAL_SETTINGS, PROD_RENDEZVOUS_SERVER, RENDEZVOUS_PORT,
    },
    socket_client::check_port,
};

pub(crate) const SERVER_REQUIRED: &str =
    "Configure your own ID server in Settings > Network, or connect directly by IP.";

pub(crate) fn init() {
    *APP_NAME.write().unwrap() = "LanternDesk".to_owned();
    HARD_SETTINGS
        .write()
        .unwrap()
        .insert("disable-account".to_owned(), "Y".to_owned());
    DEFAULT_SETTINGS
        .write()
        .unwrap()
        .insert(keys::OPTION_DIRECT_SERVER.to_owned(), "Y".to_owned());
    // These transports otherwise probe public STUN even with a private ID server.
    OVERWRITE_LOCAL_SETTINGS.write().unwrap().extend([
        (keys::OPTION_ENABLE_IPV6_PUNCH.to_owned(), "N".to_owned()),
        (keys::OPTION_ENABLE_WEBRTC.to_owned(), "N".to_owned()),
        (keys::OPTION_ENABLE_CHECK_UPDATE.to_owned(), "N".to_owned()),
    ]);
}

pub(crate) fn is_self_hosted_server(server: &str) -> bool {
    let server = server.trim();
    !server.is_empty() && !server.eq_ignore_ascii_case("public") && !crate::is_public(server)
}

fn configured_server(executable: &str, custom: &str, embedded: &str) -> String {
    [executable, custom, embedded]
        .into_iter()
        .map(str::trim)
        .find(|server| !server.is_empty())
        .filter(|server| is_self_hosted_server(server))
        .map(|server| check_port(server, RENDEZVOUS_PORT))
        .unwrap_or_default()
}

pub(crate) fn rendezvous_server() -> String {
    // Only explicit settings count; cached upstream discovery addresses must not be reused.
    configured_server(
        &EXE_RENDEZVOUS_SERVER.read().unwrap(),
        &Config::get_option(keys::OPTION_CUSTOM_RENDEZVOUS_SERVER),
        &PROD_RENDEZVOUS_SERVER.read().unwrap(),
    )
}

pub(crate) fn rendezvous_servers() -> Vec<String> {
    let server = rendezvous_server();
    if server.is_empty() {
        Vec::new()
    } else {
        vec![server]
    }
}

#[cfg(feature = "flutter")]
pub(crate) fn server_configured() -> bool {
    !configured_server(
        &EXE_RENDEZVOUS_SERVER.read().unwrap(),
        &crate::ui_interface::get_option(keys::OPTION_CUSTOM_RENDEZVOUS_SERVER),
        &PROD_RENDEZVOUS_SERVER.read().unwrap(),
    )
    .is_empty()
}

#[cfg(feature = "flutter")]
pub(crate) fn network_info() -> String {
    use crate::ui_interface::get_option;
    use hbb_common::config::option2bool;

    let mut ips = Vec::<String>::new();
    #[cfg(any(target_os = "linux", target_os = "macos", target_os = "windows"))]
    for ip in crate::platform::lantern_network::local_ipv4() {
        if !ip.is_loopback() && !ip.is_unspecified() && !ip.is_link_local() {
            let address = ip.to_string();
            if !ips.contains(&address) {
                ips.push(address);
            }
        }
    }
    let port = get_option(keys::OPTION_DIRECT_ACCESS_PORT)
        .parse::<i32>()
        .ok()
        .filter(|port| *port > 0)
        .unwrap_or(RENDEZVOUS_PORT + 2);
    serde_json::json!({
        "ips": ips,
        "port": port,
        "direct_enabled": option2bool(keys::OPTION_DIRECT_SERVER, &get_option(keys::OPTION_DIRECT_SERVER)),
    })
    .to_string()
}

#[cfg(test)]
mod tests {
    use super::configured_server;

    #[test]
    fn no_configuration_has_no_public_fallback() {
        assert_eq!(configured_server("", "", ""), "");
    }

    #[test]
    fn public_servers_are_rejected() {
        for server in [
            "rs-ny.rustdesk.com:21116",
            "https://RS-NY.RUSTDESK.COM",
            "public",
        ] {
            assert_eq!(configured_server("", server, ""), "");
        }
    }

    #[test]
    fn self_hosted_configuration_preserves_ports_and_precedence() {
        assert_eq!(
            configured_server("", " 192.168.1.10 ", ""),
            "192.168.1.10:21116"
        );
        assert_eq!(
            configured_server("", "desk.example.org:31116", ""),
            "desk.example.org:31116"
        );
        assert_eq!(
            configured_server("desk.example.org", "192.168.1.10", ""),
            "desk.example.org:21116"
        );
        assert_eq!(
            configured_server("", "", "desk.example.org"),
            "desk.example.org:21116"
        );
    }
}
