extern crate nix;

use nix::fcntl::{open, OFlag};
use nix::sys::stat::Mode;
use nix::sys::termios::{self, BaudRate, SetArg, ControlFlags, LocalFlags};
use nix::unistd::{read};
use std::path::Path;

use std::env;

const DEFAULT_TTY: &str = "/dev/ttyAMA0";
const DEFAULT_BAUD: BaudRate = BaudRate::B9600;

pub fn main() {
    let mut args = env::args();
    let port_name = args.nth(1).unwrap_or(DEFAULT_TTY.into());
    println!("Trying port={}", port_name);

    let oflag = OFlag::O_NOCTTY | OFlag::O_RDONLY;
    let port_fd = open(Path::new(&port_name), oflag, Mode::empty())
        .unwrap_or_else(|error| {
            eprintln!("Failed to open port={} error={}", port_name, error);
            ::std::process::exit(1);
        });

    // select 7bits Odd partity
    let mut port_attrs= termios::tcgetattr(port_fd).unwrap();
    port_attrs.control_flags |= ControlFlags::CS7;
    port_attrs.control_flags |= ControlFlags::PARODD;
    port_attrs.local_flags |= LocalFlags::ICANON;

    // select 9600 baud
    termios::cfsetspeed(&mut port_attrs, DEFAULT_BAUD)
        .unwrap_or_else(|error| {
            eprintln!("Failed to  setspeed= {} error={}", port_name, error);
            ::std::process::exit(1);
        });

    // push tty port_attrs to port_fd
    termios::tcsetattr(port_fd, SetArg::TCSANOW, &port_attrs)
        .unwrap_or_else(|error| {
            eprintln!("Failed to  tcgetattrport= {} error={}", port_name, error);
            ::std::process::exit(1);
        });

    println!("start reading port={}", port_name);

    loop {
        let mut buffer = [0u8; 1024];
        match read(port_fd, &mut buffer) {
            Ok(count) => {
                //let _len=write (1, &buffer);
                print! ("->{}", std::str::from_utf8(&buffer[..count]).unwrap());
            }
            Err(e) => eprintln!("{:?}", e),
        }
    }
}
