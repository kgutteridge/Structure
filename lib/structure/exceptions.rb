module Structure
  class StructureException < RuntimeError
  end

  class StructureIntegrityException < StructureException
  end
end