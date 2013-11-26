/*
 Copyright 2013 (C) Raster Software Vigo (Sergio Costas)

 This file is part of AutoVala

 AutoVala is free software; you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation; either version 3 of the License, or
 (at your option) any later version.

 AutoVala is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program.  If not, see <http://www.gnu.org/licenses/>. */

using GLib;
//using GIO;

namespace AutoVala {

	public enum packageType {NO_CHECK, DO_CHECK, LOCAL}

	public class genericElement:GLib.Object {
		public string elementName;
		public string? condition;
		public bool invertCondition;
		public bool automatic;
	}

	public class packageElement:genericElement {

		public packageType type;

		public packageElement(string package, packageType type, bool automatic, string? condition, bool inverted) {
			this.elementName=package;
			this.type=type;
			this.automatic=automatic;
			this.condition=condition;
			this.invertCondition=inverted;
		}
	}

	public class sourceElement:genericElement {

		public sourceElement(string source, bool automatic, string? condition, bool inverted) {
			this.elementName=source;
			this.automatic=automatic;
			this.condition=condition;
			this.invertCondition=inverted;
		}
	}

	public class vapiElement:genericElement {

		public vapiElement(string vapi, bool automatic, string? condition, bool inverted) {
			this.elementName=vapi;
			this.automatic=automatic;
			this.condition=condition;
			this.invertCondition=inverted;
		}
	}

	class ElementValaBinary : ElementBase {

		private string version;
		private bool versionSet;
		private bool versionAutomatic;

		private Gee.List<packageElement ?> packages;
		private Gee.List<sourceElement ?> sources;
		private Gee.List<vapiElement ?> vapis;

		private string? currentNamespace;
		private bool namespaceAutomatic;

		private string? compileOptions;
		private string? destination;

		public ElementValaBinary() {
			this.command = "";
			this.version="1.0.0";
			this.versionSet=false;
			this.versionAutomatic=true;
			this.compileOptions=null;
			this.currentNamespace=null;
			this.namespaceAutomatic=true;
			this.destination=null;
			this.packages=new Gee.ArrayList<packageElement ?>();
			this.sources=new Gee.ArrayList<sourceElement ?>();
			this.vapis=new Gee.ArrayList<vapiElement ?>();
		}

		private void transformToNonAutomatic(bool automatic) {
			if (automatic) {
				return;
			}
			this.automatic=false;
		}

		private bool checkVersion(string version) {
			return Regex.match_simple("^[0-9]+.[0-9]+(.[0-9]+)?$",version);
		}

		private bool setVersion(string version, bool automatic, int lineNumber) {

			if (this.checkVersion(version)) {
				this.version = version;
				this.versionSet = true;
				if (!automatic) {
					this.versionAutomatic=false;
				}
				this.transformToNonAutomatic(automatic);
				return false;
			} else {
				ElementBase.globalData.addError(_("Error: syntax error in VERSION statement (line %d)").printf(lineNumber));
				return true;
			}
		}

		private bool setNamespace(string namespaceT, bool automatic, int lineNumber) {
			if (this.currentNamespace==null) {
				this.currentNamespace=namespaceT;
				if (!automatic) {
					this.namespaceAutomatic=false;
				}
			} else {
				ElementBase.globalData.addWarning(_("Warning: ignoring duplicated VERSION command (line %d)").printf(lineNumber));
			}
			return false;
		}

		private bool setCompileOptions(string options, int lineNumber) {
			if (this.compileOptions==null) {
				this.compileOptions=options;
			} else {
				ElementBase.globalData.addWarning(_("Warning: ignoring duplicated OPTIONS command (line %d)").printf(lineNumber));
			}
			return false;
		}

		private bool setDestination(string destination, int lineNumber) {
			if (this.destination==null) {
				this.destination=destination;
			} else {
				ElementBase.globalData.addWarning(_("Warning: ignoring duplicated DESTINATION command (line %d)").printf(lineNumber));
			}
			return false;
		}

		private bool addPackage(string package, packageType type, bool automatic, string? condition, bool invertCondition, int lineNumber) {

			// if a package is conditional, it MUST be manual, because conditions are not added automatically
			if (condition!=null) {
				automatic=false;
			}

			// adding a non-automatic package to an automatic binary transforms this binary to non-automatic
			if ((automatic==false)&&(this.automatic==true)) {
				this.transformToNonAutomatic(false);
			}

			foreach(var element in this.packages) {
				if (element.elementName==package) {
					return false;
				}
			}

			var element=new packageElement(package,type,automatic,condition,invertCondition);
			this.packages.add(element);
			return false;
		}

		private bool addSource(string sourceFile, bool automatic, string? condition, bool invertCondition, int lineNumber) {

			if (condition!=null) {
				automatic=false; // if a source file is conditional, it MUST be manual, because conditions are not added automatically
			}

			// adding a non-automatic source to an automatic binary transforms this binary to non-automatic
			if ((automatic==false)&&(this.automatic==true)) {
				this.transformToNonAutomatic(false);
			}

			foreach(var element in this.sources) {
				if (element.elementName==sourceFile) {
					return false;
				}
			}
			var element=new sourceElement(sourceFile,automatic,condition, invertCondition);
			this.sources.add(element);
			return false;
		}

		private bool addVapi(string vapiFile, bool automatic, string? condition, bool invertCondition, int lineNumber) {

			if (condition!=null) {
				automatic=false; // if a VAPI file is conditional, it MUST be manual, because conditions are not added automatically
			}

			// adding a non-automatic VAPI to an automatic binary transforms this binary to non-automatic
			if ((automatic==false)&&(this.automatic==true)) {
				this.transformToNonAutomatic(false);
			}

			foreach(var element in this.vapis) {
				if (element.elementName==vapiFile) {
					return false;
				}
			}
			var element=new vapiElement(vapiFile,automatic,condition, invertCondition);
			this.vapis.add(element);
			return false;
		}

		public override bool configureLine(string line, bool automatic, string? condition, bool invertCondition, int lineNumber) {

			if (line.has_prefix("vala_binary: ")) {
				this._type = ConfigType.VALA_BINARY;
				this.command = "vala_binary";
			} else if (line.has_prefix("vala_library: ")) {
				this._type = ConfigType.VALA_LIBRARY;
				this.command = "vala_library";
			} else if (line.has_prefix("version: ")) {
				return this.setVersion(line.substring(9).strip(),automatic,lineNumber);
			} else if (line.has_prefix("namespace: ")) {
				return this.setNamespace(line.substring(11).strip(),automatic,lineNumber);
			} else if (line.has_prefix("compile_options: ")) {
				return this.setCompileOptions(line.substring(17).strip(),lineNumber);
			} else if (line.has_prefix("destination: ")) {
				return this.setDestination(line.substring(13).strip(),lineNumber);
			} else if (line.has_prefix("vala_package: ")) {
				return this.addPackage(line.substring(14).strip(),packageType.NO_CHECK,automatic,condition,invertCondition,lineNumber);
			} else if (line.has_prefix("vala_check_package: ")) {
				return this.addPackage(line.substring(20).strip(),packageType.DO_CHECK,automatic,condition,invertCondition,lineNumber);
			} else if (line.has_prefix("vala_local_package: ")) {
				return this.addPackage(line.substring(20).strip(),packageType.LOCAL,automatic,condition,invertCondition,lineNumber);
			} else if (line.has_prefix("vala_source: ")) {
				return this.addSource(line.substring(13).strip(),automatic,condition,invertCondition,lineNumber);
			} else if (line.has_prefix("vala_vapi: ")) {
				return this.addVapi(line.substring(11).strip(),automatic,condition,invertCondition,lineNumber);
			} else {
				var badCommand = line.split(": ")[0];
				ElementBase.globalData.addError(_("Error: invalid command %s after command %s (line %d)").printf(badCommand,this.command, lineNumber));
				return true;
			}

			var data=line.substring(2+this.command.length).strip();
			return this.configureElement(data,null,null,automatic,condition,invertCondition);
		}

		public override bool generateCMake(DataOutputStream dataStream, ConfigType type) {

			// only process this file if it is of the desired type
			if (type!=this.eType) {
				return false;
			}

			return false;
		}

		public override bool storeConfig(DataOutputStream dataStream) {

			try {
				if (this.automatic) {
					dataStream.put_string("*");
				}
				if (this._type == ConfigType.VALA_BINARY) {
					dataStream.put_string("vala_binary: %s\n".printf(this.fullPath));
				} else {
					dataStream.put_string("vala_library: %s\n".printf(this.fullPath));
				}
				if (this.versionSet) {
					if (this.versionAutomatic) {
						dataStream.put_string("*");
					}
					dataStream.put_string("version: %s\n".printf(this.version));
				}
				if (this.currentNamespace!=null) {
					if (this.namespaceAutomatic) {
						dataStream.put_string("*");
					}
					dataStream.put_string("namespace: %s\n".printf(this.currentNamespace));
				}
				if (this.compileOptions!=null) {
					dataStream.put_string("compile_options: %s\n".printf(this.compileOptions));
				}
				if (this.destination!=null) {
					dataStream.put_string("destination: %s\n".printf(this.destination));
				}
				foreach(var element in this.packages) {
					if (element.type == packageType.NO_CHECK) {
						if (element.automatic) {
							dataStream.put_string("*");
						}
						dataStream.put_string("vala_package: %s\n".printf(element.elementName));
					}
				}
				foreach(var element in this.packages) {
					if (element.type == packageType.DO_CHECK) {
						if (element.automatic) {
							dataStream.put_string("*");
						}
						dataStream.put_string("vala_check_package: %s\n".printf(element.elementName));
					}
				}
				foreach(var element in this.packages) {
					if (element.type == packageType.LOCAL) {
						if (element.automatic) {
							dataStream.put_string("*");
						}
						dataStream.put_string("vala_local_package: %s\n".printf(element.elementName));
					}
				}
				foreach(var element in this.sources) {
					if (element.automatic) {
						dataStream.put_string("*");
					}
					dataStream.put_string("vala_source: %s\n".printf(element.elementName));
				}
				foreach(var element in this.vapis) {
					if (element.automatic) {
						dataStream.put_string("*");
					}
					dataStream.put_string("vala_vapi: %s\n".printf(element.elementName));
				}
			} catch (Error e) {
				ElementBase.globalData.addError(_("Failed to store ': %s' at config").printf(this.fullPath));
				return true;
			}
			return false;
		}
	}
}
