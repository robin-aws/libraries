include "../../BoundedInts.dfy"
include "../../Wrappers.dfy"
include "Views.dfy"

module {:options "-functionSyntax:4"} JSON.Utils.Views.Writers {
  import opened BoundedInts
  import opened Wrappers

  import opened Core

  // export
  //   reveals Error, Writer
  //   provides Core, Wrappers
  //   provides Writer_, Writer_.Append, Writer_.Empty, Writer_.Valid?

  datatype Chain =
    | Empty
    | Chain(previous: Chain, v: View)
  {
    function Length() : nat {
      if Empty? then 0
      else previous.Length() + v.Length() as int
    }

    function Count() : nat {
      if Empty? then 0
      else previous.Count() + 1
    }

    function Bytes() : (bs: bytes)
      ensures |bs| == Length()
    {
      if Empty? then []
      else previous.Bytes() + v.Bytes()
    }

    function Append(v': View): (c: Chain)
      ensures c.Bytes() == Bytes() + v'.Bytes()
    {
      if Chain? && Adjacent(v, v') then
        Chain(previous, Merge(v, v'))
      else
        Chain(this, v')
    }

    method {:tailrecursion} Blit(bs: array<byte>, end: uint32)
      requires end as int == Length() <= bs.Length
      modifies bs
      ensures bs[..end] == Bytes()
      ensures bs[end..] == old(bs[end..])
    {
      if Chain? {
        var end := end - v.Length();
        v.Blit(bs, end);
        previous.Blit(bs, end);
      }
    }
  }

  type Writer = w: Writer_ | w.Valid? witness Writer(0, Chain.Empty)
  datatype Writer_ = Writer(length: uint32, chain: Chain)
  {
    static const Empty: Writer := Writer(0, Chain.Empty)

    const Empty? := chain.Empty?
    const Unsaturated? := length != UINT32_MAX

    ghost function Length() : nat { chain.Length() }

    ghost const Valid? :=
      length == // length is a saturating counter
        if chain.Length() >= TWO_TO_THE_32 then UINT32_MAX
        else chain.Length() as uint32

    function Bytes() : (bs: bytes)
      ensures |bs| == Length()
    {
      chain.Bytes()
    }

    static function SaturatedAddU32(a: uint32, b: uint32): uint32 {
      if a <= UINT32_MAX - b then a + b
      else UINT32_MAX
    }

    function {:opaque} Append(v': View): (rw: Writer)
      requires Valid?
      ensures rw.Unsaturated? <==> v'.Length() < UINT32_MAX - length
      ensures rw.Bytes() == Bytes() + v'.Bytes()
    {
      Writer(SaturatedAddU32(length, v'.Length()),
             chain.Append(v'))
    }

    function Then(fn: Writer ~> Writer) : Writer
      reads fn.reads
      requires Valid?
      requires fn.requires(this)
    {
      fn(this)
    }

    method {:tailrecursion} Blit(bs: array<byte>)
      requires Valid?
      requires Unsaturated?
      requires Length() <= bs.Length
      modifies bs
      ensures bs[..length] == Bytes()
      ensures bs[length..] == old(bs[length..])
    {
      chain.Blit(bs, length);
    }

    method ToArray() returns (bs: array<byte>)
      requires Valid?
      requires Unsaturated?
      ensures fresh(bs)
      ensures bs[..] == Bytes()
    {
      bs := new byte[length];
      Blit(bs);
    }
  }
}