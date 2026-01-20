///|
fn decode_base64_multiline(text : StringView) -> Bytes raise XlsxError {
  let compact = text.to_string().replace_all(old="\n", new="")
  base64_decode(compact)
}

///|
let encrypt_sha1_b64 =
  #|0M8R4KGxGuEAAAAAAAAAAAAAAAAAAAAAPgADAP7/CQAGAAAAAAAAAAAAAAADAAAAAQAAAAAAAAAAEAAA
  #|AgAAAAEAAAD+////AAAAAAAAAAAHAAAACAAAAP//////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|///////////////////////////////////////////9////BAAAAP7///8GAAAABQAAAP7///8ZAAAA
  #|/f////3///8KAAAACwAAAAwAAAANAAAADgAAAA8AAAAQAAAAEQAAABIAAAATAAAAFAAAABUAAAAWAAAA
  #|FwAAABgAAAD+////GgAAAP7/////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|/////1IAbwBvAHQAIABFAG4AdAByAHkAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
  #|AAAAAAAAAAAWAAUA//////////8KAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAODbfLh1f9YB
  #|AwAAAIAGAAAAAAAARQBuAGMAcgB5AHAAdABlAGQAUABhAGMAawBhAGcAZQAAAAAAAAAAAAAAAAAAAAAA
  #|AAAAAAAAAAAAAAAAAAAAACIAAgD///////////////8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
  #|AAAAAAAAAAAJAAAAmB4AAAAAAAAGAEQAYQB0AGEAUwBwAGEAYwBlAHMAAAAAAAAAAAAAAAAAAAAAAAAA
  #|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAGAABAP//////////BAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
  #|8CB4uHV/1gHganq4dX/WAQAAAAAAAAAAAAAAAFYAZQByAHMAaQBvAG4AAAAAAAAAAAAAAAAAAAAAAAAA
  #|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQAAIB////////////////AAAAAAAAAAAAAAAA
  #|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEwAAAAAAAAAAQAAAP7///8DAAAA/v////7///8GAAAA
  #|BwAAAAgAAAD+////CgAAAAsAAAAMAAAADQAAAA4AAAAPAAAAEAAAABEAAAASAAAAEwAAABQAAAAVAAAA
  #|FgAAABcAAAAYAAAAGQAAAP7/////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|//////////88AAAATQBpAGMAcgBvAHMAbwBmAHQALgBDAG8AbgB0AGEAaQBuAGUAcgAuAEQAYQB0AGEA
  #|UwBwAGEAYwBlAHMAAQAAAAEAAAABAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
  #|AAAAAAAAAAAAAAAAAAAAAAgAAAABAAAAaAAAAAEAAAAAAAAAIAAAAEUAbgBjAHIAeQBwAHQAZQBkAFAA
  #|YQBjAGsAYQBnAGUAMgAAAFMAdAByAG8AbgBnAEUAbgBjAHIAeQBwAHQAaQBvAG4ARABhAHQAYQBTAHAA
  #|YQBjAGUAAAAAAAAAAAAAAAAAAAAAAAAACAAAAAEAAAAyAAAAUwB0AHIAbwBuAGcARQBuAGMAcgB5AHAA
  #|dABpAG8AbgBUAHIAYQBuAHMAZgBvAHIAbQAAAFgAAAABAAAATAAAAHsARgBGADkAQQAzAEYAMAAzAC0A
  #|NQA2AEUARgAtADQANgAxADMALQBCAEQARAA1AC0ANQBBADQAMQBDADEARAAwADcAMgA0ADYAfQBOAAAA
  #|TQBpAGMAcgBvAHMAbwBmAHQALgBDAG8AbgB0AGEAaQBuAGUAcgAuAEUAbgBjAHIAeQBwAHQAaQBvAG4A
  #|VAByAGEAbgBzAGYAbwByAG0AAAABAAAAAQAAAAEAAAAAAAAAAAAAAEQAYQB0AGEAUwBwAGEAYwBlAE0A
  #|YQBwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAaAAIBAwAAAAUAAAD/////
  #|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAgAAAHAAAAAAAAAARABhAHQAYQBTAHAA
  #|YQBjAGUASQBuAGYAbwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABwAAQH/////
  #|BwAAAAYAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAOBqerh1f9YB4Gp6uHV/1gEAAAAAAAAAAAAAAABTAHQA
  #|cgBvAG4AZwBFAG4AYwByAHkAcAB0AGkAbwBuAEQAYQB0AGEAUwBwAGEAYwBlAAAAAAAAAAAAAAAAAAAA
  #|NAACAf///////////////wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQAAABAAAAA
  #|AAAAAFQAcgBhAG4AcwBmAG8AcgBtAEkAbgBmAG8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
  #|AAAAAAAAAAAcAAEA//////////8IAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADganq4dX/WAeBqerh1f9YB
  #|AAAAAAAAAAAAAAAAUwB0AHIAbwBuAGcARQBuAGMAcgB5AHAAdABpAG8AbgBUAHIAYQBuAHMAZgBvAHIA
  #|bQAAAAAAAAAAAAAAAAAAADQAAQH//////////wkAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAOBqerh1f9YB
  #|4Gp6uHV/1gEAAAAAAAAAAAAAAAAGAFAAcgBpAG0AYQByAHkAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
  #|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEgACAf///////////////wAAAAAAAAAAAAAAAAAAAAAAAAAA
  #|AAAAAAAAAAAAAAAAAAAAAAUAAADIAAAAAAAAAEUAbgBjAHIAeQBwAHQAaQBvAG4ASQBuAGYAbwAAAAAA
  #|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAeAAIBAgAAAAEAAAD/////AAAAAAAAAAAAAAAA
  #|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACQAAACEEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
  #|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD///////////////8AAAAA
  #|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABAAAAAAAAAAAAAAA
  #|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABAAEAEAAAAA8P3ht
  #|bCB2ZXJzaW9uPSIxLjAiIGVuY29kaW5nPSJVVEYtOCIgc3RhbmRhbG9uZT0ieWVzIj8+DQo8ZW5jcnlw
  #|dGlvbiB4bWxucz0iaHR0cDovL3NjaGVtYXMubWljcm9zb2Z0LmNvbS9vZmZpY2UvMjAwNi9lbmNyeXB0
  #|aW9uIiB4bWxuczpwPSJodHRwOi8vc2NoZW1hcy5taWNyb3NvZnQuY29tL29mZmljZS8yMDA2L2tleUVu
  #|Y3J5cHRvci9wYXNzd29yZCI+PGtleURhdGEgc2FsdFNpemU9IjE2IiBibG9ja1NpemU9IjE2IiBrZXlC
  #|aXRzPSIxMjgiIGhhc2hTaXplPSIyMCIgY2lwaGVyQWxnb3JpdGhtPSJBRVMiIGNpcGhlckNoYWluaW5n
  #|PSJDaGFpbmluZ01vZGVDQkMiIGhhc2hBbGdvcml0aG09IlNIQTEiIHNhbHRWYWx1ZT0iazJnUjdQa2pz
  #|WXZKNGFreGJTa1pSdz09Ii8+PGRhdGFJbnRlZ3JpdHkgZW5jcnlwdGVkSG1hY0tleT0iaWIxZzNIV01T
  #|dWVkU1cxbEJkeml3c1NST///////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|//////////////////////////+DHgAAAAAAABUGNYtOhqc4yUj9wgYGQV42fwvbcRbwK4nLn31yN8Yg
  #|bJEmSxo4acfo+RyD7TYTd+q2jjGAujGOHhxO6+8MXyeT77kbpNQajlHGgCnLpJ9t3F/vrQWlIcm62ONk
  #|ajmo8jSl5LZnSLB2Z8SSdlzwcPpZI2+l9P2wyBYLQPuqHwsb+KPhBHZMu6xYoYp6hvTelNV/nKrZ3ZJH
  #|onvzr3xY5dAi53ZxP6yyQm1xFmTcSOCCKNhTCXxrC+RafEt4fWFwp60R5OmVujOiYSAs9R/FFSunXVfr
  #|2yBy4DSJVqnopDYC1nV7JXY2yR1ImtgQA/pEL9x1P9g71NCDJ3CCqtWJvxjNnhNy6vVv8fYZStfS3y5w
  #|KsbtEfulmrJJCrf1eR4HGrBOzbYmep0WJMGMIeAGt68u5reuzDNte2aX8Lgb6Gf7cSM6gI0yDNstrcEQ
  #|mzdLgXiCv6ROMyY1YDZl9a7PjKc0W+099YXC/iu8zff6WQunfpxdWVryr7aIRlNY3hYTbyiOwp8shv9B
  #|L9lIXUw2+XgYdYRVXuuC6ITadtiXC1eHYrDClhxi5vyFlx/BdYGA6QoeWoY4Z/6NhsiES+ybuer1Zuia
  #|+hyC5o0Ap+rrxTQFMLwnBz1nIujXHTMnlqAPWVGOAcjxr6n/7TMyaGI7rXm975Qkd9CZNjLB799zXsG0
  #|V85nf7M/MEexFUTpT6c7X8S2HARcmC5AfdsQeu3w9LsuMXm8kXw0E2EA9NCCyPD0TLrQagxhwfoUsh2c
  #|/Gx+t6/P5M/+X02vviXpPIckZT03kR6ejTGQZu+uzAErqvF4Jdp62LGteZ7hHvqEjyYStrJSH4gtlt/k
  #|NErxszSWhjzlByftoIUa4Jv6mB7ba/0k+im5GbXTo5EXd/gNyLvmCrchR939AbgpYYSRQWQt1rZzzpYH
  #|/k0P1+kibb4BMmbyZqyym4QVCOd25pLpgrtGrtMRHj0NoqIx8gDjblU/m/tfW3i+RbiIqxToObE2tjbJ
  #|GmgqOHjba5jo8seGomvHZqGRegWqE1MZTUNnVsVsjb1+chh33ny+aCc3LzdYyqyeJjo4teXCjeGOISo1
  #|lPu53UAwPe+t2UeKHeQ6UKCyQuRVzk73k8KSSjaeg7PdAyFwBXz/JXRXgAWW/OBeqJuzmJwQigP95Nnf
  #|L0HT9CKy5cD1V35GPFTK1exfAbqrzS8ENDFQAUOmKepLWHZgAkauPp9SYX1eaztLbtOWk55TOtkt3Fq/
  #|ILkE4+8MKyoc3fA4hs3RV/wmhRF/UHfKzAd82hU7+/Tnz8Gd92upTws2Czv5mrc3V1XJB1ZAiNpoS+5U
  #|8BgLgeDbA0LJTYD/YfO+Rv+J2E28FZNeItrcFHA0nTjqXave2HJFiUP1iba8rYweiotoEPeqzkeww+io
  #|dMfksyDLLCCBXu3i7ECLj5yihX1ZZi4J42ZVTvXnvjyqOujcjsdpJGgw0tkCY9PJOltb4Yqui4l4ybyK
  #|Wu1YqPoRGLTs0DpSlbW82MyQfjcqyikIl6+2bmC9SwADzA8DOgF17FWhYzCm7mqim7MwG4geWmZ2p32T
  #|7QhNYGCZLsLQ8LrcoN1+HYEJsfZkkHy5e4EfXetMpJz7ItlPwnBJr3ieUmmBZmAOKg1pRUlX9mi2HO9t
  #|+TUG8arqaZEWIMMiMIVL/kto1nIvOW1XBW6jhtuH2kJpVYV467xlgfzVH+ewuWVespo6hu1IvmlvCyCF
  #|Luk4xz6k13bNDp1hDEOs94evCq0ehNv+S7rQG+Oq1dW3QtjtRhVIFjqxrOkhROsFnOa7RmbCyZ+5ZS67
  #|NH2N6oV8gyb1vRNfzR9IkEH/pGpbpXewYnymKGDsQoc+o8i3RU8/+1bruiFZDbHsyfs2raT3234wS64L
  #|vAWTmu4LOGGtyjUd4rD+a+DpQtj5X8LS7OOcIoVmatR/WPQcPM2Cs+q39yq3u/YiRlqtIXL+P8mpxpwm
  #|rRMl5MYoIcbv7jbF8a1Ab0rbkymxXgfT2qCO5NE9a76RehgWiy1RtHokFsnhM7nVNCtjxgtQq52h7H5h
  #|j4QcCTlpQ2KafEzwrtk7KjGoxpyBxsmHIuA6ZHHw/ZeiSCWlR4QkZhd1L8dUbiH08KNkRUc8msguqcld
  #|GVBqWlfv0M6CdF0MmU1RGRbN17c6m5GZPJM3ii6pkfc8WRHxJhkdORmuTmeqqPXdXgAdgFRZTBsivPHT
  #|cvIOv39Df9/V42jOS3WuQbOTzAfMA17U4rhq616iz9qpaskbbPYUyUdJmLMO3c0QREltvcof1YNZnOOl
  #|XeBc5J5RRsNamALNpqQKllwirhwH/VJYxB6lthQY7t0nr/3LeDXLxob0HXjXz8D58Wmxm3Xb0tSI3AiG
  #|ZDOLBuV8iE1LGS+nVhuqcdS9Rl4ssRfcgIAgytlwEbRxmiUuQmPLHr3zIFppGJAuO711B03FEBZQq6iD
  #|/I7OguswbSm72/rFccSZ+zb5RUH7LSHn+fuYerjuI3vP1tO8Xd6Mxdja8ceatmK+mHYnx6OCNk2zizKN
  #|hD6YuGBh834jEIUQpSRAzTmK7MdYZZW8Mvn9viEkrt9owO5C9rHwewlNKKVDzVWM6PHV2r6z6sEiAy/l
  #|yJ1PQ7mu2Kz9R1Vn2YYECHqSm0YfLSkERZiv7tBM2dhn6WKYWRSQqhCPz/upxB6i127CeK4mHe3VkfZN
  #|5SgjDfa1ZCLVn43bL+JLYe3HZZnp2NFKizCIxTNYFc+oa3DYk+q7N8v44FuT1MSaWpERGRtibUr2jZ3K
  #|IuICXlQOVNxzvTKDmgJfyU/OUr8Jov+n5Bp5kG44G5rFYvSJ2zfWIBdZ89GIHcc0xUTB117kFGC2RuEf
  #|MLkT+qAMti+0Z2tPAvQE3fC0uOj+kQvguf+GRrjd2m8GuWXd5/9ZRf0v0W3gktsgjYnGSCWwJ0CRsAmp
  #|i93K2pajGVWZkecMnaZTLhxGKfo5BrIo8oEZSMJ5IOXSCQdcErPifrwIVUvHF3xIiKBEXG8o4zl1YeUr
  #|ICJCEQaXR6ocNNi4Eti4VyQbF5yssK/7ksDa0+bk2z9ncTYzjy09b4NOxxOuKo+7/l6s8h2B296CFUMT
  #|W8Nznx5tokZKm5FpuzR//weZU+F+K0m2wP+zOjrnKPczS9e+0Epvpz7XPz1pNaFlsMgwCtgosvUzs+cc
  #|UoodGy6/nXQxGigbQbwrby/2CFQt91oQqq4jz+ijcvCWid+hwvADqWzM2PgE7iFefdbB5Uj8nkmTtf6J
  #|O4gZAbeDLsOsgl3SbkiOM1+Y73YdLs8Am3K9lYC0B1mrUIrmfKwPhUs+OYxzDFdYSFwA3e4bH2EjgeUI
  #|948XSelibyfiT97kP/0vsrXgf1PPINeZm5q5u4pnI95olDYIBThix7kkLpb9SO2AtbVgVtTVS6spC8Js
  #|5cYN9lei28O6aDQx/W5pgJXQQhKom2sQUtENWQjY6J+F3XS+RjUvkRnR4gwasSr53SlR1buco3sqCrpx
  #|AZnJb1vMS/7JkmYCTz2Hibsr4LsVH255eEGkddHwV5PnKtLZ/Sic//pQS3fzLgzcv5fcCQuNFuXpu7cn
  #|oo0EmLkZa1GWH4Sotpc6zPxDHsdDSV/GldCq/dayS3VAsT+zZDEdxJIvUareocqzi9sTiW1QpPTaa3sW
  #|+43L9F34pzk5MIxlOJxaA0oY7HI2yRKSXnnbUbzPoVyfzZ6I8lS/M4iAyIvd74rhvYU68Jouqz/tBuqe
  #|PhJys2ylte7BFk4MIl44Blh9zCtBxgz2xJOWApEOoGVF0nCJjRA5SC50lHMX9lil8sHXXCXVVqO4lA2o
  #|1LCWY/ONguOJvnCrMiK/NQBHgDv5RXqmf7lOnoZ+QZB/rvd3EHq5CipTy9tX76HKIzWe49fx/F0LXQAT
  #|scWYCEItUEVo/tTjOgQDfgQSXmww7b570i6zj91jhmOuuNMpQp6grye20yqE4PTpSF9R72+Es2nTpBKE
  #|pNoo3bkFgwAGnEToN6YlbOtgIDNlhyDyqsc/TwHgaMUUkFQiFJkABpMpUDczhFx6NZhY6Txk3GLnHD3C
  #|Rf6kYMrpMSqoWb1rbJ/k6j+tUtXqDVCgo/GjPp2GbX2UTC93bT78UF7Vn1Yb/vjldk/qwVhkQmT8dkdi
  #|QofCPd/MqBxHSgaafTkwikqeJYiDi91mCqMdylzyEbzxW881//xcmJ37Q2FxkQ2BcnG3Y/H6qjUygLJU
  #|WC2UH7NfhDuvOaZCPBx5hQSmfHAgX+fiRXbEJNYuvqTi4qX6r5SXRpkOBB/YTBYoyizXFZxowxlOO/FY
  #|+afsvPw3ppxNgUxX8JvPTi0g5+M11jQdweU/lG5g5NC5iDPDmlmNDXyHTUHyTyF0+ljXTH8A/VFIbT07
  #|CqzUEsvwLm98QqzbC2NPHQ1WBUkJUe93m0/0JMaX/x2xNr6d5rbTx/NrmhR8YNMjyuHa9sdeyLfk9vzJ
  #|/RChbf3QGlNUdBR+VJYWwIFfdqXf3jHkw/rT+FhLLbSIo8Y7O4AlSPz5jSiv6xXRFL3i3XBukNS6RWFE
  #|9X7pHJ9IqI+yZBkd0QzC4atf/EoY5O76X+aJopG++/hi3C1eHSVIfzEfcUeNwKpBoam2ptVhnlXNBw8a
  #|v42nkgPxb7O+ka8PgR9R21Vb9XIlFjf1IsqMKua+ZfCBjXLmIkRD21SUujQoXbuAggVGbiXYcg7ewBB8
  #|EbrmDjgrRZd/rJqmr8JF3CKTeNJtqbZ5QDn5AmFwC9IAMZmZtHpdAZbrXzsEI+03NEoIXEqG7C1L+rNC
  #|cd8EgHE0Z1WCzVadzjx8RwyN7UUQ9TtbSE61N1qq66sKXYCYFVBnOicbZDblXE8UUewfHuNBrY4iyKpF
  #|6iv1Qh6A/boY9iWEYwEF5cGwbON2Ou64OfY8Y1m4zy9K5cjYzko697hzpwLdMaBLSLQFASMoWjxbUuFU
  #|QnJ5+D5IVSDmqB6dCe+cVHfHn1WDf0wrWtDS6hYSskhe+mn7VJfQpNiGzvqn5nX02KRwh/V+JwHq+pft
  #|bCg2pE9Epz2Ok7rX6Ng5aEe28RDqjhKqlPpudq9wT+9tsYoFAjEAkHmWtzRmZGwigDFdWhWsulAfRXTD
  #|yktq+lBKA1d8QvuKyZJKdVFPZpm5FAEjJCns7xjKh08DSzQAGcmvLrY70IyCUKI26RHxJkUExf2KIYtU
  #|cRq/ra9bDTvLynCeFZSFThI35Kx2lo2BF8tuiDjOiScR8QKU6+Y+oTYYkzgpGgXbPokLXUgdcH+fpqjC
  #|eL5zao+qRM2kmyu6cCtfg6QBYiDEZXBTcBF6yvgNc++8QUpuJYYbOccIxw28Sl8cr2rp+uv1uq36w4QH
  #|GhMIZsfN6o5m3MDNS4bvvJmP8rhLiqQ6NSCWCmFtY6ai34dpcveOPw2YHmgglHw8cEx9N48Jsdx7Jb8w
  #|E6DJsU2sYnn53nHFM3LugCQRBVEOcWB2EWESMLHEFkMP/T6ep3iuz9LjqnmLEqbyP/deTVXYTMWUSCW5
  #|Clm3lMBw1bGR/iAbpzMBWdXu9L8/WS1dfbqHy9dD60BHypVwXn+aTGWv0/MXerFKobAeTx3NASN15fjr
  #|0dQrl6jl2Oe7Pt9KxP+uoAyXt5+RlWa2049iIB8WRxyca9ZqHsdKP4PTh+RksO3RXdQiar8kFEbxUfZ0
  #|/lzrj8dniRFzgQfOtU6wCDoFgULc+ac51MXkmzwpRDJQzH7FzIYoXyHeM8bIyp+V9n9+CsingDM5CIOd
  #|2d8Cz213A+4ak5YFpnWZGn/a8zC214GQGftms0FRmYiEOn02ev4uzd5l+lWVM7rZ/l5W9aEW0/1jBoBC
  #|yDXbcZ9LZO+bQy/315Zg1RadyFvsMgnZxJHXzdsAXgsaHanx5DflsN6gXUxzeha1B4jbN5NOHCONIbOw
  #|MgmmjuVh7t8nghP/9YKsh/nRxsrDae+DmtOpJbqGuW+iu3AgxNaFL/tvJR2q3g9mwunQgrrzIV7iw1pZ
  #|gPHNEVsRn7quXPEa7FWoVs8Djv2lO3i/wlolKLCzdh1Lyy9fFHAPLFU4qpjuUR/NAVpnlqJlLqtiQIYc
  #|JG9ycFzIAa/+8wbuO2tWrWmGN+6XEI43sLjjNDsmQUgny5McYgxQ56vY/Cig3TMeiwQ5Sw80zgi3UXXa
  #|JaIfuvIM7PGqGmAFwtf6rtJsiCvVJSzr1YRlq2cmAdajHU5296CFmYat8nk6MQa1i6bUAlWONSuR7nUC
  #|+yuAcoNBpANBlUT6oomDTf2RYM36gcjOYZpvaJuXo2T+LAlC0cWv3AE+uREWeJtw8G8sXzWyJlBRXCP3
  #|rhL2MGUfWtggAXHn4M+j9DQbvqEA+qG4MrViFturYY3+9cRWDKwiABWYvsdHVtCpttSF2TM9s+WPlDP5
  #|708irzhEomciYSCMhkibLOcoSDyl6m2vJS+q1SUZLEDHHHmU3kyAOPf6GRiEfnFm+0/c/jd6iFTTVBea
  #|zwTxnB6kclblCsdTu8orFh9c7oZqZH/11G71of93ZJzxN+0kJoH+g1ArxS4gBHyEORdK+3XC4aB5xPyq
  #|hY4BJj8qYWjMYWQvllD/QZEofMkKo/EbRoUK7Zx9uUU3YetohYRBRtAwEnLb27AMUyijaTydOMDKM1Oi
  #|39K55K7XTNQNQQw2cZLNx4lppHSPvkKsbZwH3PjjlobXol45FxsczYwwdqd+68NuHQJr24vIcXgfIJ3X
  #|F9jeEZYAOJ1ZIEroalv/6XqADcR8+QeW9PJdjZGN1LIe0KKaWoX6T73TyF9rKQjf0sSm3W2JgMzUwydS
  #|wEcVEmwza/8QkqsaaFP25EBsYGHOYxupKTDdqpDem1dfbErzbmOhHaFjG9Nd+Ojz4urVxjUoDM14SoCX
  #|k+9H75oBsaFvBb3EaciYWQAC3e6nagjXofsnVkqOCO1sxU+OhWHi5cwyS3TLWL6DRgKgebzVGlgHII1m
  #|WnYkERTE8HlzYJdbi3yCORDchWvqz0KFK21q/Po588MMQJimFbcpHTWSSl6c/gAYTRMKyURR5gdU8ta8
  #|u8PaLNyL6NpTqBqXjyfQXZNkAqHth6Ksp8kJyqqtfD1qnFroWy5D6DdgDZVw/8lJCDsS5VFwcAuJGNhH
  #|W32WiGwks14PmeVY1e8HpzFuKCRgdjvU1SFXR7y/JSbnKVQ21Qs+1dK13ZehIc6Rpb7CmX7IWiIMUss8
  #|h5ALuwmqb+JuF53rAj0DSmqBxw5EjqacCrANY6I1dRlBi8hOleDOKq88uR1U/va5Qfr0c2nnjk/AUe9N
  #|du4GjfDc8rk2U5A6MuHeswHlBPCVP2lIDcNa+fEr6gkbkzF4lzEZfTH9/AQ31t2YaZePb7cKEXdHmu+H
  #|UIS2bHBhDMVLvPDzg98QrRIrIAsn9+2XjZbCv2y+OzZuDz4QqjXpcxMgPQ2ee9OAK6VILqZm6ePBTrlr
  #|5V0wCabk7QvRr0DtdBkpzvO8+05FKtHKJjoWLo4NqfF3PrPgrI9OrjdN+miOIvhAAuWs51APbtp4m+QP
  #|/5RzZRVLXPp2VVTlsA4Lt3NXp6MWLzpQ8BhT4S1GobmU2/Vi07sxGKhyL2ipGI1j4cmLoFd1hf/Y6kSQ
  #|Jb4PhWWkyTm8g7fLj+9x+92rQbnxZsdXRKNGGFdZtM1OXkcnZy2wnAJmwPPJFZrzYgHdxaMMV5sTi93l
  #|QWLQ7v4kHrRVh/iRb5DPuNdXDWAQjAqxNpsBtPpbcbcxHHVPDMGIDwIwyixVKh9JAh1eiqjB8KPL9lCk
  #|VwA4A9tXBkq6/NopNViuqv/scDxD5IHDtljdJZZGdoZUFzydGdO4nfOUi8Csn1VYiqkyOSjJlq3iKjDI
  #|ReAGqSDXrNb8z6ktgnzUm08cB7epnyOWSM90sS7MCWVephxUPFFFrYc0zGK3yHKfUxnQPPW+887XrDA0
  #|JDQOu7mVbGJyjVZFI6Tx8zbL+9CmujfF0DBZpN0IEa61R8Suj1M68x6yQdMfvLZjrz1dSXglH6YVJFy3
  #|Z6pWEi5+73Bs9oMMt0U9cBfae1lXQG4d6goPRBLg4GbHrL2arZZTs9uLnCyl3ZNeXioRQu3pDgIbZpl7
  #|hkjDVgdXfEs2sZTy1i2leap6vYp4j74fUICd0VSVvP/sq0QrkjSqUtSqDoxdB+IfRYbz1E5RLMVbef0v
  #|rPdx9KBxI+ch0CUd3x8ik2w2IzO0JERGzbW/6IcwJ+GiBocEgKW5AFZhZHMpa7ag2gLB0GzmIb+a5Hrm
  #|zMHoNUUOjsW7vPOSWoQf8ts292YsRUKDUBFDlefFSDQiyV2kzPz2+U5CZBK60YnObwn59SlpvG62PfxU
  #|Goj9h9f7gV711c4sRuQPkB2oGSISiW+W3D2iTL4TETz5rduwb1+cbGF8n9g1fkKyLdrxNsBTG9U3IGhR
  #|+KwmMROhqwrZl5HWiKe3HDoQ8NzqP/tYZ6GKhE1Rt19SwP9wZcNQYDaps7APHn4OcSLoxye6vxgr8LvH
  #|mPL32/4ROR04OAU79VsMLXU8E9JJ8AklW/fe5etcKgy99mZa+tYUIWEMTuVwDUO7ktouahUIGLuK27/p
  #|elgYXfk281UcXI2575pcN+rDmfH0he2AA2tA35+cA1iSHUvN119NE3k2TvbJYG6f4KGUGOQRnILEtG3y
  #|DHaGIxOCPPjHvQpnrpH0lq0WW0yJ02w4CsJcY5TCZfIa4GHpn2j/zh6v7V4fYsk/4MOANuzDh5FV4an6
  #|bJhvYdrIvBrzgkfFqaCQth0D1rS/CnycX/GrotQzZbGunQdrU3UWopeUtlRya5EsefNcAPTSTYJmwWYV
  #|G0AuAEuvnLmbyAfBHoDXDapbqYvnkFyatb4p0mm6gh1rjEXfVrYEiUxMQGk+lrca8GqeVsDGjyWIxJsq
  #|fkhuIcgrPzcIh5aUM7T6b7Ojw5pJC41k5NAUqAkS1bKB2YA+VqJqEANrRH1AaBsAx22kVvRTG62pLy8p
  #|/ogVvZ7NzZIeaAG7CYY8ZhjEobu3o9fXP4aVInTfZ1BZo05L2IXTJZOSX93sisIlxiaQwJwefTSPOlEI
  #|gTRBsZbDq+5O7VTpcxhz2zSpo0PX2jI5249zzJxZdqDaA+DrYrazG4kOmhrxsa8RodyPnrtXuqbGSeXF
  #|XvsmAQezJJV8sYZHiL1KxVskQinDx3t7wCzhaLkwjYIcVm5Nqb85EGWNI9ifdA/ZAizG4dnC7+EAcpuy
  #|TaOCFimd5+r6Tz/nyuzDlppnkO6HUbScMiajU67z/U173C78r1CudaOqLHGjrvCUMRdsi+4JpNAqedHs
  #|0tGB7O0WfldAzG7Ry+8DKn+phMl+x3va9/6x4nkOl6lmx+6k2a+vTOSI0M3DT7Mahe3g+H/tq0BopXL0
  #|QePZ4mWbcmQiaG29k500ONtsEmjQ4+Y8VMYZOHppuwhBcN/7lgNG9i+S2EdDwrxGdw8IEoWJ8BgUbOlj
  #|l3iutwmJaSDSmwaWhZMJ6bXug35Cymj1JsxrXNarpqYK6PexTGMWDxMnnvcEEm5qnlQCxDCQEAQK+V4s
  #|ifeBoHQLGqvEqKvOlGfe0ZLYzHF6EGJVfsIMkd7pqNv7hDhDQhnVvC6esF0NmKlEvLd0ym/6L/vq+nr7
  #|kLfUpA4W1yHUHxx3YwyARxKkU3UJPo7zf987j8MJj/uS6m0hNWA/peiXbTwosZIZaEIMqt//xA50cg0J
  #|ZG4twBmF5a+ABCPZxEN+X3uD+oteHofI09Xn9JJ117ejkbVefDl3QAHIWw8lLVHj+Uz3Xcq18b1Kfote
  #|alhN1x2Isk6aWDrOJEXcamUt0nMHj3jt/YVL7dI4fFtrlN7LQ6IqVfSGHcOfXtTFRfqczVCCJ2RJRo5g
  #|qKM6O59cza7C8yoolp4TqbbtvHyLMWElexVC8QsdBLrmqxEw5qTfTYtf1jsq6cgCfRa+s01KqaOF6rOo
  #|2i/ogUrUcKY5R3fAGRIk/20Usqa9ptwbrVVymn7IPCxY8LidPevxwGdXKzDIKh2h1WliCbi/NVjEC4KM
  #|AixwK45M0icknKWlpU8+dHdcrQcuzwMAb9HdaaQTF+1G/umPjlPmMxH3OyKXm69fkQiyyCe47SiT0VkH
  #|C3IBNz4KjJAeDhv9BqtXvEb2HLKYLqtgYrNJrOIGN2dtZ5fz/vupY9n1LeEqKtLrMsG/lrY5Q8CV1d+Z
  #|KsZe0AORGc03BT9IVnyHsgWIz10QVr9JfzhG1qu2x/Bj2vCP3k8RbBQLL5cjVF6pW5OcdEJLx0wyLR5x
  #|2qWvhVr5RSZuQQaAetD33qRhkQgSMSO4G7l0phYL/uG9TQZCdMk/my3zzcqxcItQCTFU0T25OUlw46kh
  #|31FZeurDNgR0EP+YS0qb8X7xMispNZ5Y+ps/8PJAg7lElkmBbKwbCeSkW/8cbvqii5JqLD9V7+If4P7J
  #|Gnv595kXIeeAizsskhF2EL39JPdFFWGijBYZm1DbeENIVafSaOSSvlpnX3HMzuWnrl+tBuOiJh0jv980
  #|WpeoAX9opSZXC5E6wp2IX6dr5y7UnALQje5umxuM5Ps4lRHQg96rR6yr3utzgg0zcwyFxxpkBscrq3u9
  #|5ZBHrY4y5UbykSf1eoO1pEr61TkR0oLKryL/9P1QDnR+FCNwM81xbPlbjRbH4kBvJLX76etcdkUnCWf1
  #|gQK+Ska2p760HmEt2kBhValRe99yF4u3maIoONxYuG4v6mR0ib1jUsPYFPYPKhxgkMrn/6Vu1xOh6h9C
  #|FbEhvj3mOvKUAG1usWSdHQdVZlhTmMuFXMSVz+RVtAchv6W6TG6ktVTrzuQwbOH3nC07R28n2LhFCsXU
  #|LxpxSWef5KzUAlPYheI3HthSnRWsNr3GsOp2pJXJIz/9g0uQrCRmucXH3Fc46oIFAF/KwLGAnh4o6ui/
  #|JX8mWzs08uzdypnT+x6UN8Dvs6S5vYz7A9eB1gacMkjV9nav+ccM6q6Mm09WhX1cUuTm1WNTN1AxeFpp
  #|Y2NkUTZueEJlbz0iIGVuY3J5cHRlZEhtYWNWYWx1ZT0iaEdsV3JrR1p1K0ttTUV4U0ZsRG1QbnFJNlB6
  #|RHJrWm5zNWJjQmx2NmVwMD0iLz48a2V5RW5jcnlwdG9ycz48a2V5RW5jcnlwdG9yIHVyaT0iaHR0cDov
  #|L3NjaGVtYXMubWljcm9zb2Z0LmNvbS9vZmZpY2UvMjAwNi9rZXlFbmNyeXB0b3IvcGFzc3dvcmQiPjxw
  #|OmVuY3J5cHRlZEtleSBzcGluQ291bnQ9IjEwMDAwMCIgc2FsdFNpemU9IjE2IiBibG9ja1NpemU9IjE2
  #|IiBrZXlCaXRzPSIxMjgiIGhhc2hTaXplPSIyMCIgY2lwaGVyQWxnb3JpdGhtPSJBRVMiIGNpcGhlckNo
  #|YWluaW5nPSJDaGFpbmluZ01vZGVDQkMiIGhhc2hBbGdvcml0aG09IlNIQTEiIHNhbHRWYWx1ZT0iV29v
  #|WUNRNmhvRFIyZ0VSOXp3RFZLdz09IiBlbmNyeXB0ZWRWZXJpZmllckhhc2hJbnB1dD0iYnB6YWJ3akho
  #|K3UrZmx4TXRzcHpoZz09IiBlbmNyeXB0ZWRWZXJpZmllckhhc2hWYWx1ZT0iN0QycnJybmhTWXAvNjFI
  #|Z2o2L3VQaTRHV1paN2lmMGE3K1QvQ1BOMTJLdz0iIGVuY3J5cHRlZEtleVZhbHVlPSI4OWwxbHdrTlla
  #|QnVrL2tZTmV1R1dBPT0iLz48L2tleUVuY3J5cHRvcj48L2tleUVuY3J5cHRvcnM+PC9lbmNyeXB0aW9u
  #|PgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
  #|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
  #|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
  #|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
  #|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
  #|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
  #|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=
  #|

///|
let encrypt_aes_b64 =
  #|0M8R4KGxGuEAAAAAAAAAAAAAAAAAAAAAOwADAP7/CQAGAAAAAAAAAAAAAAABAAAADgAAAAAAAAAAEAAA
  #|AgAAAAEAAAD+////AAAAAAAAAAD/////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|///////////////////////////////////////////9//////////7////+////BQAAAAYAAAAHAAAA
  #|CAAAAAkAAAAKAAAACwAAAAwAAAANAAAA/v////7/////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|/////1IAbwBvAHQAIABFAG4AdAByAHkAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
  #|AAAAAAAAAAAWAAUA////////////////AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
  #|/v///wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
  #|AAAAAAAAAAAAAAAAAAAAAAAAAAD///////////////8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
  #|AAAAAAAAAAD+////AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
  #|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAP///////////////wAAAAAAAAAAAAAAAAAAAAAAAAAA
  #|AAAAAAAAAAAAAAAAAAAAAP7///8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
  #|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA////////////////AAAAAAAAAAAAAAAA
  #|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA/v///wAAAAAAAAAAAQAAAAIAAAADAAAA/v//////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|////////////////////////////////////////////////////////////////////////////////
  #|//////////8DAAIAJAAAAIwAAAAkAAAAAAAAAA5mAAAEgAAAgAAAABgAAAAAAAAAAAAAAE0AaQBjAHIA
  #|bwBzAG8AZgB0ACAARQBuAGgAYQBuAGMAZQBkACAAUgBTAEEAIABhAG4AZAAgAEEARQBTACAAQwByAHkA
  #|cAB0AG8AZwByAGEAcABoAGkAYwAgAFAAcgBvAHYAaQBkAGUAcgAAABAAAAAo4CLFrKeTKjf5ZIUDZKhs
  #|9kAmMAo4s1aL5kf7JzTjiRQAAACzHs4Lxi8EGKGeGW8k5Viv38RyvBDXznGdpnFMBNfB3wAAAAAAAAAA
  #|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
  #|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
  #|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
  #|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
  #|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACESAAAAAAAAbUJcpy+h0iUeSNh0
  #|/tUILIIqSptUp6a1IebgVi86XVUpG+f3J+sHlgy2bAyrSIQfHB2wKMvRLiUb1XXO+mIuAG2/kqO/Pmdo
  #|+LpQDRaxxgfZKfLnsdCUuMSgffqZce1FX6ooKNJuLbLnOgChhUxU7xPGReN8Wqk0k0cryLfMsK5gy/aC
  #|UudnwEa6yHhAhtO+5A/Q8JGt9alYL7vTwnZVpuB2vJI2u1Ja2EQBdjomBSLe3I4RWWBG+iAsZpedpXFj
  #|7vtFx35qGoUt6OKsy3ZBn+S7WMRhWk3eSis7T89LgAA6ElmN24QYlI7mg5sPD+yF1j1RCPr0SjMpjneT
  #|K6U1zEjya0j4wt+PubMrHuxcdSVdZBpI+xbC20wby2N3FmhroteGkFM1Dbx/dsdakawncIvs8TW+S7I+
  #|+4tvecZmxtl/FEkmzJy+Q0w2JIAr/IJRzngarUZdXzFO/cJ8kyld0l4k9OOQc61d8FPMtZsfr6a3pz4A
  #|EF+l1tdvNKDBZeLjJTVBuz1DsFW0w+kv+oRaCXPgm0hHOC5u8WwqkVeqc7WofDnP7zgX0OCSP1E4nkRV
  #|8pdBdOcR9uqXPuZ0NDpRGUq17D3m9SuUyfJhAnBdK2PqGJ4+OKNzwjigiF4zRTsll05KgcdV5yYf6fdl
  #|rmKgzzfMT38QPYck6PuZlosc7hVJZuPH0GM9rkVKVg0eLkZMJugzRknLEqqHiMXZZKpbML0Na1zSiS0u
  #|GdrlMLJw48Fj5TWdmg5BvfnHadF9nz8WLLqBcQEIcR38N0DRgAqF7wtgD5Py5Qh35bmWmiLV5IHO7bcn
  #|+OhBOxfJsHDEm53pT1JRdYGq9+tgULs0VLzCp7wReUFU9FC6UKhsGeoaiFBYO0PhiQpWJtpVM0Nh8goi
  #|aAK7VjW9qq/glfnA/F4rikCiVPh/dbBA61+GBxagk39A2SJ8e7hlDhsScZF468HiCwW4yzK6JajUCKGb
  #|z7yftlKcdwFjX3/32piwVxS/gs0wTap6pD/7wcjhtvyQMzrkrUM/fBILKJZjTW0odcGsWymPq1F+koqz
  #|z3+EE3DvLBt7di2qtHQBwjBN9Vc/QIkHkJOQkJk3U9c2x1xipG0FtCBPzl8njk0FXGVVTk1tPdhk4drz
  #|1fkEPKIR6Z5sJPnxjJYIQq1qjvyYPONzg4L+pNiVeqzQDvVcmKJOunQsbWtxj55AWmN1Q4t673/QHO1y
  #|Bov9oPRn3A+Hy9JQXKQTFBuw1u8jImUCirMb3HjS1d/y2xL7t6sfnA4UTLR6GWEGO94lR8PgZESbhv6v
  #|6wUl8vqWki9/+PvkC+n7GE+xUpF1iRKhYA35GqJHSVk4NSCGR4qaMoT3xgxAaj7JgF11Z/yJk+9kaxsS
  #|hcSphxxh70tgrKtFzWfxqgGbB2raDysCM3Z+Q7zijcZGrbANh6EKXBI/KyROBN1TCGlU9XopuHD5pxM3
  #|jgDfwEf+7vqxQYK0hx08LHghmAMLE8fRTz5Ya7T6VSQqMb5/apTbcfh7rJIX1kfhKP8LyF3OKiSrnZVa
  #|MtYuBnQ2QkfMzKZgbV/6i++UAoMUDJjP1JIdOLSpbu+niU8FgI/zb8frqV1+EiCclrtK7lcnMqL6HNjv
  #|V+nhW+M3EvwO3dbmzBk5kB4WBQM7uDvHFI/BFN6StRA6aMPDCukxRWwI1Y2tKpswq8l98anz/rWbamMJ
  #|9dcCIt6in21+aOeD4cYoWIvBlHhoezw9Q46WTeCoIrFKKAjsEZ2CePRX9/6+0HsEkfwTQ4Qt32Bpr6Fr
  #|Wwy/yVl87I6TrvOR1IJ2USyIBYsJe5LaEh3UqjfBH1MJQQCADMkwm5W6aMWAZs77nm1LwsVmjXP2nUbs
  #|pXoj2UgAAU7ItLlMoPctFK20Hk2uzZPBzH/6TDuPQdpNVTTrFTHEvCe8wg5ckUCRdCpo25zPUFe/3M8v
  #|tcbcBB1MDXW9RlE6RuzpdtkOFGmOPsUNU3ukcvAAGa8W9q+0FlIjzQ9zoJLcSzKekf+PiioYiZBCU4Gw
  #|ltPpjfm0vXu8Ei/TnO7xPTubo/z08ukB1zqtGjqE+1VpDPrZJ+um2xSqIYmWL1uEwC3OLX15SIgXFb7U
  #|LtmVTYB5OpCbqslzLIdoLGsDAOk0035Uzmp3vRhE7UYJVXXsYT8sAmunDEIkzxUsmtcUMEx5mwaIpTDO
  #|JhORySsr0xE2W9f4f54HIWJYb0IvzQtM2cJbiQsSQUm3Z7C6NtcOisRw7ZRpGm021XlQGkuPBSL6Cqvj
  #|E/vO3BP+n1qHb/6UAURpz+uJqSVqi6Hm/fNc9js6MmTwN2WEvx2I3e2mgptNfgNevrV9o3aQGqjP+haI
  #|iiwzm+N1UdA0MXapJGhWyWcPxW+sRg5utFZqzLN61cCG8i8+lECElRoDJcv143Fmws/CnGf+6B+1zY3K
  #|sb6ygXGyl8eqE7eAy9oCuO/+BP5sndhbvIdrFJOLL7OBqR+ZqSydZ+larO/CblUQbpfqVV6i9RtXy1zx
  #|nZHOnSOmj20GtcKRPLNsrfoaXPbYMP0aAbWU3KACWur7VRN/tgALplyLKnJDuhPAmG2ONDEqIK2ENxKg
  #|fIDW5MUSTmSZoLrdF6xiWsQZmhX4h2h1LPSAwmX+7p0Jaf9bKKAiUUkHcopufGNij2Ug33Gm663BpPJx
  #|8SO5GfOCt0cbV3pYAdCOGRuednyFqnIvOza5FZMZVYHlcUKRUqbevf13xGZBX/LoAiDsCfxAkdYAcwrp
  #|LqwoktSWifvWrmUIqWWdZkfqJBs6Psatu6HHWExQ76Qy+3vNPXkyP5vOqlIU9y3HD/9nkBaYcXBB9kbw
  #|4xyzIpKyvXIWb84uAjbwpEzBk2eINphYWath02oQOs7KH0vFgcZ7BDJYrzh2g4BqYFrHT1xT5sIG6j/f
  #|vBj/1gRZ60ZuNpqvCR8cvnN9dAvogDNxStb3n9FICy17warNFq+9P2aPyVO0/WbOH7Nys1aGTwUMhRDd
  #|2opfvfom6EeRdiyTkN9IPa48ifvJPJLULtsmzVBxoy8PFQC6vkjOyA3FYGpGClYfJWOWf2csiy0qU3i5
  #|d3eIdK2IEMSQqcymOFx8rapxo2XPoyqmcliDsw1WHOKamnFXYMqpVsPEs1tC4Nzp8FIML0QjnWuoG1Jh
  #|Yox72p4r60Rpd6vhB5Ne+JMDeJzpyH5nKZk4Ssz0o+tK++tjDcSAuhFeg9wV2hTq6L4sLqiSnlp8Uf1E
  #|+3vxGSt8b3VT7mQ8Qd9Ot5uYpZdjQDP+i7YM8ttl9mKX043hXOoxNRz06mkc+A2pMqV3SUsGY1QMtQdi
  #|Q8yxDMMoKJXP3QRdxlB5q/PNzkqB8USvO3QCUUZ+OKbomQ8ULv3Wa3YReI0HMqD7Bi04kTnCG+NQsB+V
  #|UIW44Mn1NUaXNvxX2cfPVxy3qdAiq7IuV0JSVoP95nPj7RdpDRU/6XCEzER5SiTYXvU/izLPZsYkzyyG
  #|aIjR15joiHTYaPj9ISqKR5VDch6gstWVboqOQFQ00XagQxlPonn/C+MBm0ZvGoK2r8semj6hyXaoLmkc
  #|R6lYwmG0x7vgFL5Bf896dhC8mb0bQJNrT+a3sUxTTAtZJxALZ2KGKxmjxj2uXq1j0Si01fcKDtLFvHQr
  #|h2gxVwgMCxhQyWYLbsCDi4669Mj2kj9fq+aGYKJGjG3a5lLi3URGFQhFTwChL0HT4hGuhlHyPWqtF+wf
  #|1nqN8BZafkS38mAMx3StowYU8FYjYolPS2EVoHVPoa07vZhwySLzxuWRzksDVk7BZ2QSi0QcMPIygZD+
  #|R4GAEthSI5u64VuyM2VnGU+QDx9cfB980fLLagOi4/upUZmF9bNk1bkATTOjX91drPWm2p7YeslVYouT
  #|IDll1EJUbhk9PJpJKbyT6rSF5HTPLqDxmnsH0ppvMdpsxgK0ndyuau2NlPjBGR+e9PNmQidoUPsLRpW+
  #|7n9ft0pyoNhJ5DdVz26gRlsVlwDq48vJoJ6Db7KfW2Rx9VN+650Ilq2xvOU73dAn7iWOL7Zqcig7h3MF
  #|Sw5VjeoTw9vRPXCt739cf4N1DIMJZ1mTC+9FJSA5s6ZdvlL9P9ZhHt3b4KuTksy5+sjsDpSqjI3zMdVJ
  #|JxiopBtm9Crbz5ZzikmBPEGyXl/ey1UJ2inKrEWlOJlI1bZmIftBWQ/jpDX9qOp/DbsI+2MIv56h3OCj
  #|VpLNfJwErT5wv4swqDTIMU7GllxKF4S3ouw1sNGTCM+HhnmqYd+aJH70eU28d2P3BR9w6GLYBJmXEWYs
  #|Cy0242Z8lVc/AnjPOw42mHhMH/5QHQU1XN9wmtF3rFuhafqK8ZHn8CS7H+9T66k07k/o+RKfFhnaKl6e
  #|B4ZDCT+8vCNn8lid4A9l2cyRy1zzx+Ve6TJ9NB+c/CN4P7AruB9k1g5RhmQ8lI0ejI+QeGXNIJo5P7SO
  #|8LFPGLIzL+t/9stp6pZ2EaBI5d2psFb6h5tToL9cf88DU8HM0a4aIJwC4tJOlEHHENE6VSy87gTQGY0g
  #|+XZ4UFFBrCzn4z7kFdtm8kLaPiFPY5T5oRCXK7iO7oPInN9S2UYOv2pho+PeczslWE4XkfO/gRZx3Oxc
  #|0lGfoGNtSbJ7QBau8QHdBvkecbcdtchhV/KitB5lDRgploThPJvdHUa3hejVZR4+u649WCnAavNr9rIc
  #|kmehOJzbZ56gusl40RB6InVW/fjWZO8AhGNSeyvkJfDLKqQZfrc3fKCmqFr2ErrVWylRfABulcok+zTj
  #|8+j9VlYmEOONbNi/IyoFDe4Y8kWQPjCfzSZcATg/rVteXqP4Pb3LikGQvSB8Lb/wu2hLPYpcoE7wHD4h
  #|/5G0RczTlbI1ciJkOBCo/XOqgRIZugs+vCU5Ci83DYCxzULO32Wc+XmDFMl5o8SVDt0ogFx9BVjsZhV/
  #|cLOeFIcC/JaKJv7wN2SjXMENVnc0AgRBx1lpbz0MFthCkr4jGR/c5isUZ8jYWMYU6PJGtXgjVS+xzo+C
  #|GWBde9ywcIR1dsmmPZRt1TWL/6KaRD30xAfETVpOZG0ciqjZLUuaL17snvJKMOOzvHGoEYci4Jqf9W66
  #|KgtybiZKUZzyMy6iSKpabPZu96figx3jNCPfWsvTvSxykr+7ejklEFBEdrTz9vVeOdBRVge2BbSSJF5E
  #|OzaJYVEwLg+MxTWQ0cWdzSsn2Lgd0SWhrjFPsBx18pPekPEBAFUGAMAdu3lFVtU3LI6kJoTsumK9UTg9
  #|X3PPQM5T23kYpN6WTC+JhhNousJyj16DgOJvQlsRJGCQONbBpYTnRqbqnHZFvh9URGcYfa6QUhdjE6mb
  #|4omx4ZX6lnQpXcVpiJ4EiVSg7w55hX6bNr9+4+ahVv1LSm74f7eAEYbitR6hPt08POxjfy5OMZdSJhp/
  #|x1zy9O049dWd9ouelXSI4xzoUYeA502uMNv2zVsV/I8CiIaEdMVpXY/w5DK3rKUY0GTU8/ckCEEskDuv
  #|TnoYBl9v6Is8Z7XeV8afs47d04uLjRp8TcoBRSuoKqKe1AQrCruiXay0WL8G9KqIVp7oFX1OR8Bgt82K
  #|EuarfyVEflWji+SMD5bYNYNGhnreEIK5FRWLjHRv3Iv+z758EVsK/wVa1AZtu1RIKWmfPX5veyQSa4U8
  #|5kcZ+Bx0ui+UU4+f1iQILAldcgQBnV7FsXOwuTOVZTE4fcz2fvamzD416IfKjDJI4hCQlKzNISxfqLZ4
  #|22nCIu16O4NSEFwvEB468l9v6Is8Z7XeV8afs47d04s7l9lFcJE84FDvlcfjQhRqoLMI09UvmKEDt6JR
  #|3HhpRJ8ZKHnPAz4y4Sle2nM0QXarXKcqvdtqfu/be1QMicCH21WHs9lZcKwT+ir+FfJRahUKhLcPtOtS
  #|/Tiw3dS7FMKTT5bU20uI4d0sDnyrPoDKFBlE31BfpD+Ayyeff2uVcgPcw4wsQFOyIXQxf4UbNcJs7Alq
  #|3tDv/iwJ4vQoKywCgOQjFwXwHupPsA5/Odx5EzWSii/N9bAsnkz/ixTyFHVU7CCrKtmly0YWy9RAI0LY
  #|j/zGG8wEsaVt3fwIAzI7u2rp+LaaBt/pJXzc1DqJBNW1aXqyqWA5kM3hzd+O9NEKIVkmvmJNBikbu/rc
  #|VwErDGcbYKiCW5Ox7PHmuviMaowd4YITk4eJEPMN067pxBIL1/SexonPPdugMo1Qy0KcPOLpZyg5l8l0
  #|isSVDuQEacWcNiJBjbC1bNLKfrDR2pTyAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
  #|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
  #|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
  #|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
  #|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
  #|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
  #|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
  #|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
  #|UgBvAG8AdAAgAEUAbgB0AHIAeQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
  #|AAAAABYABQD//////////wEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADAAAA
  #|AAEAAAAAAABFAG4AYwByAHkAcAB0AGkAbwBuAEkAbgBmAG8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
  #|AAAAAAAAAAAAAAAAHgACAP////8CAAAA/////wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
  #|AAAAAAAAAADgAAAAAAAAAEUAbgBjAHIAeQBwAHQAZQBkAFAAYQBjAGsAYQBnAGUAAAAAAAAAAAAAAAAA
  #|AAAAAAAAAAAAAAAAAAAAAAAAAAAiAAIA////////////////AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
  #|AAAAAAAAAAAAAAAABAAAADgSAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
  #|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD///////////////8AAAAAAAAAAAAAAAAAAAAA
  #|AAAAAAAAAAAAAAAAAAAAAAAAAAD+////AAAAAAAAAAA=
  #|

///|
test "encryption info detection" {
  let bytes = decode_base64_multiline(encrypt_sha1_b64)
  inspect(bytes.length(), content="14336")
  let reader = cfb_read(bytes)
  let info = reader.read_stream("EncryptionInfo")
  let is_agile = match encryption_mechanism(info) {
    EncryptionMechanism::Agile => true
    EncryptionMechanism::Standard => false
  }
  inspect(is_agile, content="true")
  let xml = @encoding/utf8.decode(info[8:])
  inspect(xml.contains("<encryption"), content="true")
  inspect(
    xml.contains("saltValue=\"k2gR7PkjsYvJ4akxbSkZRw==\""),
    content="true",
  )
}

///|
test "encryption info standard detection" {
  let bytes = decode_base64_multiline(encrypt_aes_b64)
  inspect(bytes.length(), content="8192")
  let reader = cfb_read(bytes)
  let info = reader.read_stream("EncryptionInfo")
  let is_standard = match encryption_mechanism(info) {
    EncryptionMechanism::Standard => true
    EncryptionMechanism::Agile => false
  }
  inspect(is_standard, content="true")
}

///|
test "read encrypted agile workbook" {
  let bytes = decode_base64_multiline(encrypt_sha1_b64)
  let workbook = read_with_password(bytes, "password")
  let sheet = match workbook.sheet("Sheet1") {
    Some(value) => value
    None => fail("missing Sheet1")
  }
  inspect(sheet.get_cell("A1"), content="Some(\"SECRET\")")
}

///|
test "read encrypted standard workbook" {
  let bytes = decode_base64_multiline(encrypt_aes_b64)
  let workbook = read_with_password(bytes, "password")
  inspect(workbook.sheets().length() > 0, content="true")
}

///|
test "decrypt agile zip read" {
  let bytes = decode_base64_multiline(encrypt_sha1_b64)
  let decrypted = decrypt_encrypted_package(bytes, "password")
  let result : Result[@zip.Archive, Error] = try? @zip.read(decrypted)
  inspect(result is Ok(_), content="true")
}

///|
test "decrypt standard zip read" {
  let bytes = decode_base64_multiline(encrypt_aes_b64)
  let decrypted = decrypt_encrypted_package(bytes, "password")
  let result : Result[@zip.Archive, Error] = try? @zip.read(decrypted)
  match result {
    Ok(archive) =>
      inspect(archive.get("xl/workbook.xml") is Some(_), content="true")
    Err(_) => inspect(false, content="true")
  }
}

///|
test "decrypt standard workbook parse" {
  let bytes = decode_base64_multiline(encrypt_aes_b64)
  let decrypted = decrypt_encrypted_package(bytes, "password")
  let result : Result[Workbook, Error] = try? read_zip_bytes(decrypted)
  inspect(result is Ok(_), content="true")
}

///|
test "read encrypted wrong password" {
  let bytes = decode_base64_multiline(encrypt_sha1_b64)
  let result : Result[Workbook, Error] = try? read_with_password(bytes, "wrong")
  inspect(result is Err(XlsxError::InvalidPassword), content="true")
}

///|
test "read encrypted without password" {
  let bytes = decode_base64_multiline(encrypt_sha1_b64)
  let result : Result[Workbook, Error] = try? read(bytes)
  inspect(result is Err(XlsxError::EncryptedPackage), content="true")
}

///|
test "write encrypted roundtrip" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell("A1", "SECRET")
  let encrypted = write_with_password(workbook, "passwd")
  let decoded = read_with_password(encrypted, "passwd")
  let decoded_sheet = match decoded.sheet("Sheet1") {
    Some(value) => value
    None => fail("missing Sheet1")
  }
  inspect(decoded_sheet.get_cell("A1"), content="Some(\"SECRET\")")
}

///|
test "write encrypted invalid password length" {
  let workbook = Workbook::new()
  let long_password = "*".repeat(256)
  let result : Result[Bytes, Error] = try? write_with_password(
    workbook, long_password,
  )
  inspect(result is Err(XlsxError::InvalidPasswordLength(_)), content="true")
}
