#!/usr/bin/env python
"""
Converts a set of Objective-C headers commented using TomDoc to headers documented using Doxygen or Appledoc
"""
__author__ = 'Whirliwig'
__license__ = "MIT"
__version__ = "0.5"
__email__ = "ant@dervishsoftware.com"

DEBUG = False
verbose = False

import sys
from optparse import OptionParser
from glob import glob
from os import path, makedirs
from collections import OrderedDict
import re


def debug_log(log_message):
    if DEBUG:
        print(log_message)

# From http://code.activeself.state.com/recipes/410692/
class switch(object):
    def __init__(self, value):
        self.value = value
        self.fall = False

    def __iter__(self):
        yield self.match
        raise StopIteration

    def match(self, *args):
        if self.fall or not args:
            return True
        elif self.value in args:
            self.fall = True
            return True
        else:
            return False


# States for inside class declaration
OUTSIDE_COMMENT = 0
INSIDE_COMMENT = 1
BRIEF_DESCRIPTION = 2
DETAILED_DESCRIPTION = 3
PARAM_DESCRIPTION = 4
EXAMPLES_SECTION = 5
RETURN_DESCRIPTION = 6

# Top-level states
OUTSIDE_CLASS_DECL = 0
INSIDE_CLASS_DECL = 1


class CommentBlock(object):
    def __init__(self):
        self.params = OrderedDict()
        self.brief = ''
        self.detail = ''
        self.param_name = None
        self.param_description = ''
        self.return_description = ''
        self.examples = ''

    def has_brief(self):
        return len(self.brief) > 0

    def has_detail(self):
        return len(self.detail) > 0

    def has_return(self):
        return len(self.return_description) > 0

    def has_params(self):
        return len(self.params) > 0

    def has_examples(self):
        return len(self.examples) > 0

    def has_non_brief_content(self):
        return self.has_detail() or self.has_params() or self.has_examples() or self.has_return()

    def has_content(self):
        return self.has_brief() or self.has_non_brief_content()

    def set_current_param(self, name=None, desc=''):
        if self.param_name:
            self.params[self.param_name] = self.param_description
        self.param_description = desc
        self.param_name = name


class HeaderParser(object):
    comment_line_regex = re.compile("^(?:/\\*\\*?|//)\\s*(.*)")
    interface_regex = re.compile(r'^\s*@interface\s+(\w+(?:\s+:)|\w+\s*\(\w+\))')
    end_regex = re.compile(r'^\s*@end')
    param_regex = re.compile(r'(\w+)\s+-\s+(.+)$')
    return_regex = re.compile(r'[Rr]eturns\s+(.+)$')
    examples_regex = re.compile(r'^\s*Example[s:]')
    list_regex = re.compile(r'^[\-1-9\*]\.?\s')


    def __init__(self, file_handle, header_name=None):
        self.input_file_handle = file_handle
        self.header_name = header_name
        self.state = OUTSIDE_COMMENT
        self.outer_state = OUTSIDE_CLASS_DECL
        self.comment = CommentBlock()


    def next_section(self, content):
        return_matches = HeaderParser.return_regex.match(content)
        new_state = None
        if return_matches:
            self.comment.set_current_param()
            debug_log(">>>>Start of returns: {}".format(content))
            self.comment.return_description = return_matches.group(1)
            new_state = RETURN_DESCRIPTION
        else:
            param_matches = HeaderParser.param_regex.match(content)
            if param_matches:
                self.comment.set_current_param(param_matches.group(1), param_matches.group(2))
                debug_log(">>>>Param: {} = {}".format(self.comment.param_name, self.comment.param_description))
                new_state = PARAM_DESCRIPTION
            else:
                if HeaderParser.examples_regex.match(content):
                    self.comment.detail += '\n**Examples**\n'
                    self.comment.set_current_param()
                    debug_log(">>>>Start of examples: {}".format(content))
                    new_state = EXAMPLES_SECTION
        return new_state


    def parse(self, output_file_handle, source_code_formatter):
        if self.header_name and verbose: print "Parsing {}".format(self.header_name)

        saved_comment = ''
        for line in self.input_file_handle:
            line = line.strip()

            matches = HeaderParser.comment_line_regex.match(line)
            if matches or (len(line) == 0 and self.state != OUTSIDE_COMMENT):
                if matches:
                    content = matches.group(1)

                for case in switch(self.state):
                    if case(OUTSIDE_COMMENT, INSIDE_COMMENT):
                        if content:
                            new_state = self.next_section(content)
                            if not new_state:
                                debug_log(">>>>Brief: {}".format(content))
                                self.state = BRIEF_DESCRIPTION
                                self.comment.brief = ' '.join([self.comment.brief, content])
                            else:
                                self.state = new_state
                        else:
                            self.state = INSIDE_COMMENT
                    elif case(BRIEF_DESCRIPTION):
                        if not content:
                            debug_log("<<<<End Brief")
                            self.state = DETAILED_DESCRIPTION
                        else:
                            self.comment.brief = ' '.join([self.comment.brief, content])

                    elif case(DETAILED_DESCRIPTION):
                        if content:
                            new_state = self.next_section(content)
                            if not new_state:
                                debug_log(">>>>Detail: {}".format(content))
                                if HeaderParser.list_regex.match(content):
                                    self.comment.detail += '\n'
                                else:
                                    self.comment.detail += ' '
                                self.comment.detail += content
                            else:
                                self.state = new_state
                        else:
                            self.comment.detail = '{}\n'.format(self.comment.detail)

                    elif case(EXAMPLES_SECTION):
                        if content:
                            new_state = self.next_section(content)
                            if not new_state:
                                debug_log(">>>>Examples: {}".format(content))
                                self.comment.examples += '\n'
                                self.comment.examples += content
                            else:
                                self.state = new_state
                        else:
                            self.comment.examples = '{}\n'.format(self.comment.examples)

                    elif case(PARAM_DESCRIPTION):
                        if content:
                            new_state = self.next_section(content)
                            if not new_state:
                                debug_log(">>>>Param: {}".format(content))
                                self.comment.param_description = ' '.join([self.comment.param_description, content])
                            else:
                                self.state = new_state
                        else:
                            debug_log("<<<<End Param {}".format(self.comment.param_name))
                            self.comment.set_current_param()
                            self.state = DETAILED_DESCRIPTION
                    elif case(RETURN_DESCRIPTION):
                        if content:
                            debug_log(">>>>Return: {}".format(content))
                            self.comment.return_description = ' '.join([self.comment.return_description, content])
                        else:
                            self.state = DETAILED_DESCRIPTION

                if self.state is not OUTSIDE_COMMENT:
                    saved_comment += line
                    saved_comment += '\n'

            else: # Not a comment line
                if_matches = HeaderParser.interface_regex.match(line)
                if if_matches:
                    self.outer_state = INSIDE_CLASS_DECL
                    if self.state == OUTSIDE_COMMENT:
                        output_file_handle.write(source_code_formatter.single_line_comment(
                            'Documentation for {}'.format(if_matches.group(1))))

                if self.state != OUTSIDE_COMMENT:
                    debug_log("Leaving comment")

                    if self.outer_state == INSIDE_CLASS_DECL and self.comment.has_content():
                        # Process comment here
                        formatted_comment = source_code_formatter.format_source(self.comment)
                        if formatted_comment:
                            output_file_handle.write(formatted_comment)
                    elif self.comment.has_content():
                        # A comment outside a class declaration will be printed verbatim
                        output_file_handle.write(saved_comment)

                    self.comment = CommentBlock()
                    saved_comment = ''
                    self.state = OUTSIDE_COMMENT

                if HeaderParser.end_regex.match(line) and self.outer_state == INSIDE_CLASS_DECL:
                    self.outer_state = OUTSIDE_CLASS_DECL

                output_file_handle.write('{}\n'.format(line))


class SourceCodeFormatter(object):
    def format_source(self, comment):
        pass


class DoxygenSourceCodeFormatter(SourceCodeFormatter):
    def format_source(self, comment):
        output = None
        if not comment.has_brief() and comment.has_return():
            comment.brief = 'Returns {}'.format(comment.return_description.split('.')[0])

        if comment.has_brief():
            output = '//! {}'.format(comment.brief.strip())

        if comment.has_non_brief_content():
            output += '\n/*!\n'
            if comment.has_detail():
                detail_sections = comment.detail.strip().split('\n')
                for detail_section in detail_sections:
                    output += ' *  {}\n *\n'.format(detail_section.strip())
            if comment.has_examples():
                output += ' * \code\n'
                output += '\n'.join([' * {}'.format(x) for x in comment.examples.strip().split('\n')])
                output += '\n * \endcode\n'
            if comment.has_params():
                for param_name, param_description in comment.params.items():
                    output += ' *  \param {} {}\n *\n'.format(param_name, param_description)
            if comment.has_return():
                output += ' *  \\return {}\n'.format(comment.return_description)
            output += ' */'
        output += '\n'
        if DEBUG:
            print output
        return output

    def single_line_comment(self, content):
        return '//! {}\n'.format(content)


class AppledocSourceCodeFormatter(SourceCodeFormatter):
    selector_regex = re.compile(r'(\[[\w :+\-]+\])')
    class_regex = re.compile(r'(\s)(RAC\w+)\b')

    def add_crossrefs(self, comment):
        #comment = AppledocSourceCodeFormatter.selector_regex.sub(r' \1 ',comment)
        #comment = AppledocSourceCodeFormatter.class_regex.sub(r'\1\2 ',comment)
        return comment

    def format_source(self, comment):
        output = None
        if not comment.has_brief() and comment.has_return():
            comment.brief = 'Returns {}'.format(comment.return_description.split('.')[0])

        if comment.has_brief():
            output = '/** {}'.format(self.add_crossrefs(comment.brief.strip()))
            if not comment.has_non_brief_content():
                output += ' */'

        if comment.has_non_brief_content():
            output += '\n *\n'
            if comment.has_detail():
                detail_sections = self.add_crossrefs(comment.detail.strip()).split('\n')
                for detail_section in detail_sections:
                    output += ' *  {}\n *\n'.format(detail_section.strip())
            if comment.has_examples():
                output += '\n'.join([' *\t{}'.format(x) for x in comment.examples.strip().split('\n')])
            if comment.has_params():
                for param_name, param_description in comment.params.items():
                    output += ' *  \param {} {}\n *\n'.format(param_name, self.add_crossrefs(param_description))
            if comment.has_return():
                output += ' *  \\return {}\n'.format(self.add_crossrefs(comment.return_description))
            output += ' */'
        output += '\n'
        if DEBUG:
            print output
        return output

    def single_line_comment(self, content):
        return '/** {} */\n'.format(content)


def main():
    parser = OptionParser(usage="usage: %prog [options] filenames|directory",
                          version="%prog 1.0")
    parser.add_option("-o", "--outputdir",
                      action="store", # optional because action defaults to "store"
                      dest="outputdir",
                      default=None,
                      help="The directory to put output files", )
    parser.add_option("-a", "--appledoc",
                      action="store_true",
                      dest="appledoc",
                      default=False,
                      help="Generate Appledoc output", )
    parser.add_option("-d", "--doxygen",
                      action="store_true",
                      dest="doxygen",
                      default=False,
                      help="Generate Doxygen output", )
    parser.add_option("-v", "--verbose",
                      action="store_true",
                      dest="verbose",
                      default=False,
                      help="Turn on verbose output", )
    (options, args) = parser.parse_args()

    use_stdin = False
    use_stdout = False

    if len(args) == 0:
        use_stdin = True

    if (use_stdin and not options.outputdir) or options.outputdir == '-':
        use_stdout = True

    if not use_stdin:
        input_paths = [path.abspath(p) for p in args]
        if len(input_paths) > 1:
            common_prefix = path.commonprefix(*input_paths)
            common_prefix_len = len(common_prefix)
        else:
            common_prefix_len = len(input_paths[0]) - len(path.basename(input_paths[0]))

        if options.outputdir:
            output_dir = path.abspath(options.outputdir)
        else:
            output_dir = path.abspath('./formatted_headers')

        if not options.appledoc and not options.doxygen:
            print("Must specify --appledoc or --doxygen")
            parser.usage()
            sys.exit(1)

        if options.appledoc:
            source_code_formatter = AppledocSourceCodeFormatter()
        else:
            source_code_formatter = DoxygenSourceCodeFormatter()

        if not use_stdout and not path.exists(output_dir):
            makedirs(output_dir)

        verbose=options.verbose

        for header_path in input_paths:
            if path.isdir(header_path):
                files = glob(path.join(header_path, '*'))
            else:
                files = [header_path]

            files = [f for f in files if path.isfile(f) and path.splitext(f)[1] == '.h']

            for header_file in files:
                relative_path = header_file[common_prefix_len:]
                if not use_stdout:
                    output_file = path.join(output_dir, relative_path)
                    write_dir = path.dirname(output_file)
                    if not path.exists(write_dir):
                        makedirs(path.dirname(output_file))

                    with open(header_file, 'rU') as input_file_handle:
                        with open(output_file, 'w') as output_file_handle:
                            if verbose: print("Converting {} --> {}".format(header_file, output_file))
                            header_parser = HeaderParser(input_file_handle, path.basename(header_file))
                            header_parser.parse(output_file_handle, source_code_formatter)
                else:
                    with open(header_file, 'rU') as input_file_handle:
                        header_parser = HeaderParser(input_file_handle, path.basename(header_file))
                        header_parser.parse(sys.stdout, source_code_formatter)
    else:
        header_parser = HeaderParser(sys.stdin)
        header_parser.parse(sys.stdout)


if __name__ == '__main__':
    main()

