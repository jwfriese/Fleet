Pod::Spec.new do |s|
  s.name                    = "Fleet"
  s.version                 = "4.2.0"
  s.summary                 = "A UIKit-focused Swift testing framework"
  s.homepage                = "https://github.com/jwfriese/Fleet"
  s.license                 = { :type => "Apache 2.0", :file => "LICENSE" }
  s.author                  = "Jared Friese"
  s.ios.deployment_target   = "8.0"
  s.tvos.deployment_target  = "10.0"
  s.source                  = { :git => "https://github.com/jwfriese/Fleet.git", :tag => "#{s.version}" }
  s.source_files            = "Fleet/**/*.{swift,h,m}"
  s.public_header_files     = ["Fleet/Fleet.h", "Fleet/ObjC/FleetObjC.h"]
  s.preserve_paths          = "Fleet/Script/copy_storyboard_info_files.sh"

  s.tvos.exclude_files = [
    "Fleet/CoreExtensions/TableView/UITableViewRowAction+Fleet.m",
    "Fleet/CoreExtensions/TableView/UITableView+SelectCellAction.swift",
    "Fleet/CoreExtensions/TableView/UITableViewRowAction+Fleet.swift",
    "Fleet/CoreExtensions/Controls/TextInput/UITextField+Fleet.swift",
    "Fleet/CoreExtensions/Controls/TextInput/UITextView+Fleet.swift",
    "Fleet/CoreExtensions/Controls/UISwitch+Fleet.swift",
  ]
end
