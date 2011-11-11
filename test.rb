require 'libvirt'

conn = Libvirt::open("qemu:///system")
puts conn.capabilities


conn.create_domain_linux(File.read('test.xml'))

dom = conn.lookup_domain_by_name("mydomain")
dom.suspend
dom.resume
puts dom.xml_desc
