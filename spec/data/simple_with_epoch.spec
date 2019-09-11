%define debug_package %{nil}

Name:           simple_with_epoch
Version:        1.0
Release:        0
License:        GPL
Summary:        Simple dummy package
Url:            http://www.dummmy.com
Group:          Development
BuildRoot:      %{_tmppath}/%{name}-%{version}-build
Epoch:          11
BuildArch:      noarch

%description
Dummy package

%prep

%build

%install
mkdir -p %{buildroot}%{_datadir}/%{name}
echo "Hello" > %{buildroot}%{_datadir}/%{name}/README
echo "Hola" > %{buildroot}%{_datadir}/%{name}/README.es

%clean
%{?buildroot:%__rm -rf "%{buildroot}"}

%files
%defattr(-,root,root)
%{_datadir}/%{name}/README
%{_datadir}/%{name}/README.es

%changelog
* Sun Nov 06 2011 Duncan Mac-Vicar P. <dmacvicar@suse.de>
- Fix something

* Sat Nov 05 2011 Duncan Mac-Vicar P. <dmacvicar@suse.de>
- Fix something else
