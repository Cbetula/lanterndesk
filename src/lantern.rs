use hbb_common::config::{APP_NAME, HARD_SETTINGS};

pub(crate) fn init() {
    *APP_NAME.write().unwrap() = "LanternDesk".to_owned();
    HARD_SETTINGS
        .write()
        .unwrap()
        .insert("disable-account".to_owned(), "Y".to_owned());
}
