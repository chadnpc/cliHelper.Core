function Read-WbemErrorCode {
  [CmdletBinding()][OutputType([string])]
  param (
    [WbemErrorCode]$ErrorCode
  )

  begin {
    $code_descriptions = [System.Management.Automation.OrderedHashtable]@{
      0          = 'The call was successful.'
      2147749889 = 'The call failed.'
      2147749890 = 'The object could not be found.'
      2147749891 = 'The current user does not have permission to perform the action.'
      2147749892 = 'The provider has failed at some time other than during initialization.'
      2147749893 = 'A type mismatch occurred.'
      2147749894 = 'There was not enough memory for the operation.'
      2147749895 = 'The SWbemNamedValue object is not valid.'
      2147749896 = 'One of the parameters to the call is not correct.'
      2147749897 = 'The resource, typically a remote server, is not currently available.'
      2147749898 = 'An internal, critical, and unexpected error occurred. Report this error to Microsoft Technical Support.'
      2147749899 = 'One or more network packets were corrupted during a remote session.'
      2147749900 = 'The feature or operation is not supported.'
      2147749901 = 'The parent class specified is not valid.'
      2147749902 = 'The namespace specified could not be found.'
      2147749903 = 'The specified instance is not valid.'
      2147749904 = 'The specified class is not valid.'
      2147749905 = 'A provider referenced in the schema does not have a corresponding registration.'
      2147749906 = 'A provider referenced in the schema has an incorrect or incomplete registration. This error may be caused by a missing pragma namespace command in the MOF file used to register the provider, resulting in the provider being registered in the wrong WMI namespace. This error may also be caused by a corrupt repository, which may be fixed by deleting it and recompiling the MOF files.'
      2147749907 = 'COM cannot locate a provider referenced in the schema.'
      2147749908 = 'A component, such as a provider, failed to initialize for internal reasons.'
      2147749909 = 'A networking error occurred, preventing normal operation.'
      2147749910 = 'The requested operation is not valid. This error usually applies to invalid attempts to delete classes or properties.'
      2147749911 = 'The requested operation is not valid. This error usually applies to invalid attempts to delete classes or properties.'
      2147749912 = 'The requested query language is not supported.'
      2147749913 = 'In a put operation, the wbemChangeFlagCreateOnly flag was specified, but the instance already exists.'
      2147749914 = 'It is not possible to perform the add operation on this qualifier because the owning object does not permit overrides.'
      2147749915 = 'The user attempted to delete a qualifier that was not owned. The qualifier was inherited from a parent class.'
      2147749916 = 'The user attempted to delete a property that was not owned. The property was inherited from a parent class.'
      2147749917 = 'The client made an unexpected and illegal sequence of calls, such as calling EndEnumeration before calling BeginEnumeration.'
      2147749918 = 'The user requested an illegal operation, such as spawning a class from an instance.'
      2147749919 = 'There was an illegal attempt to specify a key qualifier on a property that cannot be a key. The keys are specified in the class definition for an object, and cannot be altered on a per-instance basis.'
      2147749920 = 'The current object is not a valid class definition. Either it is incomplete, or it has not been registered with WMI using SWbemObject.Put_.'
      2147749921 = 'The syntax of an input parameter is incorrect for the applicable data structure. For example, when a CIM datetime structure does not have the correct format when passed to SWbemDateTime.SetFileTime.'
      2147749922 = 'Reserved for future use.'
      2147749923 = 'The property that you are attempting to modify is read-only.'
      2147749924 = 'The provider cannot perform the requested operation. This would include a query that is too complex, retrieving an instance, creating or updating a class, deleting a class, or enumerating a class.'
      2147749925 = 'An attempt was made to make a change that would invalidate a subclass.'
      2147749926 = 'An attempt has been made to delete or modify a class that has instances.'
      2147749927 = 'Reserved for future use.'
      2147749928 = 'A value of Nothing was specified for a property that may not be Nothing, such as one that is marked by a Key, Indexed, or Not_Null qualifier.'
      2147749929 = 'The CIM type specified for a property is not valid.'
      2147749930 = 'The CIM type specified for a property is not valid.'
      2147749931 = 'The request was made with an out-of-range value, or is incompatible with the type.'
      2147749932 = 'An illegal attempt was made to make a class singleton, such as when the class is derived from a non-singleton class.'
      2147749933 = 'The CIM type specified is not valid.'
      2147749934 = 'The requested method is not available.'
      2147749935 = 'The parameters provided for the method are not valid.'
      2147749936 = 'There was an attempt to get qualifiers on a system property.'
      2147749937 = 'The property type is not recognized.'
      2147749938 = 'An asynchronous process has been canceled internally or by the user. Note that due to the timing and nature of the asynchronous operation the operation may not have been truly canceled.'
      2147749939 = 'The user has requested an operation while WMI is in the process of shutting down.'
      2147749940 = 'An attempt was made to reuse an existing method name from a parent class, and the signatures did not match.'
      2147749941 = 'One or more parameter values, such as a query text, is too complex or unsupported. WMI is therefore requested to retry the operation with simpler parameters.'
      2147749942 = 'A parameter was missing from the method call.'
      2147749943 = 'A method parameter has an ID qualifier that is not valid.'
      2147749944 = 'One or more of the method parameters have ID qualifiers that are out of sequence.'
      2147749945 = 'The return value for a method has an ID qualifier.'
      2147749946 = 'The specified object path was not valid.'
      2147749947 = 'Disk is out of space or the 4 GB limit on WMI repository (CIM repository) size is reached.'
      2147749948 = 'The supplied buffer was too small to hold all the objects in the enumerator or to read a string property.'
      2147749949 = 'The provider does not support the requested put operation.'
      2147749950 = 'An object with an incorrect type or version was encountered during marshaling.'
      2147749951 = 'A packet with an incorrect type or version was encountered during marshaling.'
      2147749952 = 'The packet has an unsupported version.'
      2147749953 = 'The packet appears to be corrupted.'
      2147749954 = 'An attempt has been made to mismatch qualifiers, such as putting [key] on an object instead of a property.'
      2147749955 = 'A duplicate parameter has been declared in a CIM method.'
      2147749956 = 'Reserved for future use.'
      2147749957 = 'A call to IWbemObjectSink::Indicate has failed. The provider may choose to refire the event.'
      2147749958 = 'The specified flavor was not valid.'
      2147749959 = 'An attempt has been made to create a reference that is circular (for example, deriving a class from itself).'
      2147749960 = 'The specified class is not supported.'
      2147749961 = 'An attempt was made to change a key when instances or subclasses are already using the key.'
      2147749968 = 'An attempt was made to change an index when instances or subclasses are already using the index.'
      2147749969 = 'An attempt was made to create more properties than the current version of the class supports.'
      2147749970 = 'A property was redefined with a conflicting type in a derived class.'
      2147749971 = 'An attempt was made in a derived class to override a non-overrideable qualifier.'
      2147749972 = 'A method was redeclared with a conflicting signature in a derived class.'
      2147749973 = 'An attempt was made to execute a method not marked with [implemented] in any relevant class.'
      2147749974 = 'An attempt was made to execute a method marked with [disabled].'
      2147749975 = 'The refresher is busy with another operation.'
      2147749976 = 'The filtering query is syntactically not valid.'
      2147749977 = 'The FROM clause of a filtering query references a class that is not an event class (not derived from __Event).'
      2147749978 = 'A GROUP BY clause was used without the corresponding GROUP WITHIN clause.'
      2147749979 = 'A GROUP BY clause was used. Aggregation on all properties is not supported.'
      2147749980 = 'Dot notation was used on a property that is not an embedded object.'
      2147749981 = 'A GROUP BY clause references a property that is an embedded object without using dot notation.'
      2147749983 = 'An event provider registration query (__EventProviderRegistration) did not specify the classes for which events were provided.'
      2147749984 = 'An request was made to back up or restore the repository while WMI was using it.'
      2147749985 = 'The asynchronous delivery queue overflowed due to the event consumer being too slow.'
      2147749986 = 'The operation failed because the client did not have the necessary security privilege.'
      2147749987 = 'The operator is not valid for this property type.'
      2147749988 = 'The user specified a username, password or authority for a local connection. The user must use a blank username/password and rely on default security.'
      2147749989 = 'The class was made abstract when its parent class is not abstract.'
      2147749990 = 'An amended object was put without the wbemFlagUseAmendedQualifiers flag being specified.'
      2147749991 = 'The client was not retrieving objects quickly enough from an enumeration. This constant is returned when a client creates an enumeration object but does not retrieve objects from the enumerator in a timely fashion, causing the enumerators object caches to get backed up.'
      2147749992 = 'A null security descriptor was used.'
      2147749993 = 'The operation timed out.'
      2147749994 = 'The association being used is not valid.'
      2147749995 = 'The operation was ambiguous.'
      2147749996 = 'WMI is taking up too much memory. This could be caused either by low memory availability or excessive memory consumption by WMI.'
      2147749997 = 'The operation resulted in a transaction conflict.'
      2147749998 = 'The transaction forced a rollback.'
      2147749999 = 'The locale used in the call is not supported.'
      2147750000 = 'The object handle is out of date.'
      2147750001 = 'Indicates that the connection to the SQL database failed.'
      2147750002 = 'The handle request was not valid.'
      2147750003 = 'The property name contains more than 255 characters.'
      2147750004 = 'The class name contains more than 255 characters.'
      2147750005 = 'The method name contains more than 255 characters.'
      2147750006 = 'The qualifier name contains more than 255 characters.'
      2147750007 = 'Indicates that an SQL command should be rerun because there is a deadlock in SQL. This can be returned only when data is being stored in an SQL database.'
      2147750008 = 'The database version does not match the version that the repository driver processes.'
      2147750009 = 'WMI cannot do the delete operation because the provider does not allow it.'
      2147750010 = 'WMI cannot do the put operation because the provider does not allow it.'
      2147750016 = 'The specified locale identifier was not valid for the operation.'
      2147750017 = 'The provider is suspended.'
      2147750018 = 'The object must be committed and retrieved again before the requested operation can succeed. This constant is returned when an object must be committed and re-retrieved to see the property value.'
      2147750019 = 'The operation cannot be completed because no schema is available.'
      2147750020 = 'The provider registration cannot be done because the provider is already registered.'
      2147750021 = 'The provider for the requested data is not registered.'
      2147750022 = 'A fatal transport error occurred and other transport will not be attempted.'
      2147750023 = 'The client connection to WINMGMT must be encrypted for this operation. The IWbemServices proxy security settings should be adjusted and the operation retried.'
      2147750024 = 'A provider failed to report results within the specified timeout. See WBEM_E_PROVIDER_TIMED_OUT in WMI Error Constants.'
      2147750025 = 'User attempted to put an instance with no defined key. See WBEM_E_NO_KEY in WMI Error Constants.'
      2147750026 = 'User attempted to register a provider instance but the COM server for the provider instance was unloaded. See WBEM_E_PROVIDER_DISABLED in WMI Error Constants.'
      2147753985 = 'The provider registration overlaps with the system event domain.'
      2147753986 = 'A WITHIN clause was not used in this query.'
      2147758081 = 'Automation-specific error.'
      2147758082 = 'The user deleted an override default value for the current class. The default value for this property in the parent class has been reactivated. An automation-specific error.'
    }
  }

  process {
    return $code_descriptions[$Code]
  }
}
