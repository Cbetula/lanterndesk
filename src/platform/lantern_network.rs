use std::net::Ipv4Addr;

#[cfg(unix)]
pub(crate) fn local_ipv4() -> Vec<Ipv4Addr> {
    use hbb_common::libc;

    let mut addresses = Vec::new();
    let mut head = std::ptr::null_mut();
    // Enumerate locally: default-net probes a public IP to choose the default route on Unix.
    if unsafe { libc::getifaddrs(&mut head) } != 0 {
        hbb_common::throttled_log!(std::time::Duration::from_secs(60), warn,
            "Cannot list local IP addresses: {}", std::io::Error::last_os_error());
        return addresses;
    }
    let mut current = head;
    while !current.is_null() {
        // getifaddrs owns this list until freeifaddrs; AF_INET entries contain sockaddr_in.
        let interface = unsafe { &*current };
        if interface.ifa_flags & libc::IFF_UP as libc::c_uint != 0
            && !interface.ifa_addr.is_null()
            && unsafe { (*interface.ifa_addr).sa_family as i32 } == libc::AF_INET
        {
            let address = unsafe { &*(interface.ifa_addr as *const libc::sockaddr_in) };
            addresses.push(Ipv4Addr::from(address.sin_addr.s_addr.to_ne_bytes()));
        }
        current = interface.ifa_next;
    }
    unsafe { libc::freeifaddrs(head) };
    addresses
}

#[cfg(windows)]
pub(crate) fn local_ipv4() -> Vec<Ipv4Addr> {
    default_net::get_interfaces()
        .into_iter()
        .flat_map(|interface| interface.ipv4.into_iter().map(|network| network.addr))
        .collect()
}
