{application, procket,
    [
        {description,"Low level socket operations"},
            {vsn,"0.3"},
            {modules,[bpf,packet,procket,procket_ioctl,procket_mktmp]},
            {registered, []},
            {applications, [crypto]}
    ]
}.